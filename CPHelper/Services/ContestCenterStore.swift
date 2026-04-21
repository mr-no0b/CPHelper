import Combine
import Foundation
import UserNotifications

@MainActor
final class ContestCenterStore: ObservableObject {
    enum PermissionState: Equatable {
        case unknown
        case granted
        case denied
    }

    @Published private(set) var upcomingContests: [CodeforcesContest] = []
    @Published private(set) var reminderFeed: [ContestReminderItem] = []
    @Published private(set) var unreadCount = 0
    @Published private(set) var permissionState: PermissionState = .unknown
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    private let contestService: CodeforcesContestService
    private let notificationCenter: UNUserNotificationCenter
    private let requestPrefix = "cphelper.contest."

    private var lastUser: UserProfile?

    init(
        contestService: CodeforcesContestService = .shared,
        notificationCenter: UNUserNotificationCenter = .current()
    ) {
        self.contestService = contestService
        self.notificationCenter = notificationCenter

        Task {
            await refreshPermissionState()
        }
    }

    func requestAuthorizationIfNeeded() async {
        await refreshPermissionState()
        guard permissionState == .unknown else { return }

        let granted = await requestAuthorization()
        permissionState = granted ? .granted : .denied

        if let lastUser {
            await refresh(for: lastUser, force: false)
        }
    }

    func refresh(for user: UserProfile?, force: Bool = false) async {
        lastUser = user
        await refreshPermissionState()

        guard let user else {
            upcomingContests = []
            reminderFeed = []
            unreadCount = 0
            errorMessage = nil
            await clearScheduledRequests()
            return
        }

        guard !isLoading else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            let contests = try await contestService.loadUpcomingContests(forceRefresh: force)
            upcomingContests = contests
            reminderFeed = buildReminderFeed(contests: contests, user: user)
            unreadCount = reminderFeed.filter { $0.isDue() && !isReminderRead($0, user: user) }.count
            errorMessage = nil

            if permissionState == .granted {
                await scheduleNotifications(for: reminderFeed)
            } else {
                await clearScheduledRequests()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func markFeedAsRead(for user: UserProfile?) {
        guard let user else { return }

        let dueIDs = reminderFeed
            .filter { $0.isDue() }
            .map(\.id)

        var ids = readIDs(for: user)
        ids.formUnion(dueIDs)
        saveReadIDs(ids, for: user)
        unreadCount = reminderFeed.filter { $0.isDue() && !ids.contains($0.id) }.count
    }

    func isRegistered(for contest: CodeforcesContest, user: UserProfile?) -> Bool {
        user?.isRegistered(for: contest.id) ?? false
    }

    func registrationSummary(for contest: CodeforcesContest, user: UserProfile?) -> String {
        guard let user else {
            return "Sign in to track contest registration."
        }

        guard let primaryHandle = user.primaryHandle, !primaryHandle.isEmpty else {
            return "Set your primary handle."
        }

        return user.isRegistered(for: contest.id)
            ? "@\(primaryHandle) marked registered"
            : "@\(primaryHandle) still needs registration"
    }

    private func buildReminderFeed(
        contests: [CodeforcesContest],
        user: UserProfile
    ) -> [ContestReminderItem] {
        contests.flatMap { contest in
            reminderItems(for: contest, user: user)
        }
        .sorted { lhs, rhs in
            if lhs.scheduledDate == rhs.scheduledDate {
                return lhs.contest.startTime < rhs.contest.startTime
            }
            return lhs.scheduledDate < rhs.scheduledDate
        }
    }

    private func reminderItems(
        for contest: CodeforcesContest,
        user: UserProfile
    ) -> [ContestReminderItem] {
        let primaryHandle = user.primaryHandle?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let needsRegistration = !primaryHandle.isEmpty && !user.isRegistered(for: contest.id)

        let items: [ContestReminderItem?] = [
            ContestReminderItem(
                contest: contest,
                kind: .dayBefore,
                scheduledDate: contest.startTime.addingTimeInterval(-ContestReminderKind.dayBefore.leadTime),
                title: "\(ContestReminderKind.dayBefore.titlePrefix): \(contest.name)",
                message: "Starts in 24 hours.",
                severity: .neutral
            ),
            needsRegistration ? ContestReminderItem(
                contest: contest,
                kind: .threeHours,
                scheduledDate: contest.startTime.addingTimeInterval(-ContestReminderKind.threeHours.leadTime),
                title: "\(ContestReminderKind.threeHours.titlePrefix): \(contest.name)",
                message: "@\(primaryHandle) is still not marked registered.",
                severity: .warning
            ) : nil,
            ContestReminderItem(
                contest: contest,
                kind: .finalHour,
                scheduledDate: contest.startTime.addingTimeInterval(-ContestReminderKind.finalHour.leadTime),
                title: "\(ContestReminderKind.finalHour.titlePrefix): \(contest.name)",
                message: needsRegistration
                    ? "@\(primaryHandle) still needs registration."
                    : "1 hour left.",
                severity: needsRegistration ? .danger : .neutral
            )
        ]

        return items.compactMap { item in
            guard let item else { return nil }
            return item.scheduledDate < contest.startTime ? item : nil
        }
    }

    private func scheduleNotifications(for reminders: [ContestReminderItem]) async {
        await clearScheduledRequests()

        let futureReminders = reminders
            .filter { $0.scheduledDate > .now }
            .prefix(20)

        for reminder in futureReminders {
            let content = UNMutableNotificationContent()
            content.title = reminder.title
            content.body = reminder.message
            content.sound = .default

            let triggerDate = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute],
                from: reminder.scheduledDate
            )

            let trigger = UNCalendarNotificationTrigger(dateMatching: triggerDate, repeats: false)
            let request = UNNotificationRequest(
                identifier: requestPrefix + reminder.id,
                content: content,
                trigger: trigger
            )

            try? await addNotificationRequest(request)
        }
    }

    private func clearScheduledRequests() async {
        let identifiers = await pendingNotificationIdentifiers()
            .filter { $0.hasPrefix(requestPrefix) }

        guard !identifiers.isEmpty else { return }
        notificationCenter.removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    private func isReminderRead(_ reminder: ContestReminderItem, user: UserProfile) -> Bool {
        readIDs(for: user).contains(reminder.id)
    }

    private func readIDs(for user: UserProfile) -> Set<String> {
        let values = UserDefaults.standard.stringArray(forKey: readIDsKey(for: user.email)) ?? []
        return Set(values)
    }

    private func saveReadIDs(_ ids: Set<String>, for user: UserProfile) {
        UserDefaults.standard.set(Array(ids), forKey: readIDsKey(for: user.email))
    }

    private func readIDsKey(for email: String) -> String {
        "cphelper.read-reminders.\(email.lowercased())"
    }

    private func refreshPermissionState() async {
        let settings = await currentNotificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            permissionState = .granted
        case .denied:
            permissionState = .denied
        case .notDetermined:
            permissionState = .unknown
        @unknown default:
            permissionState = .unknown
        }
    }

    private func currentNotificationSettings() async -> UNNotificationSettings {
        await withCheckedContinuation { continuation in
            notificationCenter.getNotificationSettings { settings in
                continuation.resume(returning: settings)
            }
        }
    }

    private func requestAuthorization() async -> Bool {
        await withCheckedContinuation { continuation in
            notificationCenter.requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
                continuation.resume(returning: granted)
            }
        }
    }

    private func addNotificationRequest(_ request: UNNotificationRequest) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            notificationCenter.add(request) { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }

    private func pendingNotificationIdentifiers() async -> [String] {
        await withCheckedContinuation { continuation in
            notificationCenter.getPendingNotificationRequests { requests in
                continuation.resume(returning: requests.map(\.identifier))
            }
        }
    }
}
