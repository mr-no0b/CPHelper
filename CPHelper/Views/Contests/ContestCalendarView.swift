import SwiftUI

struct ContestCalendarView: View {
    @EnvironmentObject private var contestCenter: ContestCenterStore
    @EnvironmentObject private var sessionStore: SessionStore

    @State private var webDestination: WebDestination?
    @State private var updatingRegistrationID: String?

    private var handles: [TrackedHandle] {
        sessionStore.currentUser?.handles ?? []
    }

    private struct ContestDayGroup: Identifiable {
        let day: Date
        let contests: [CodeforcesContest]

        var id: Date { day }
    }

    private var groupedContests: [ContestDayGroup] {
        let groups = Dictionary(grouping: contestCenter.upcomingContests.prefix(16)) { contest in
            Calendar.current.startOfDay(for: contest.startTime)
        }

        return groups.keys.sorted().map { day in
            ContestDayGroup(
                day: day,
                contests: groups[day]?.sorted { $0.startTime < $1.startTime } ?? []
            )
        }
    }

    var body: some View {
        ZStack {
            AppBackdrop()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    heroCard

                    if contestCenter.isLoading && contestCenter.upcomingContests.isEmpty {
                        InlineMessageCard(
                            icon: "calendar.badge.clock",
                            title: "Loading upcoming contests",
                            detail: "Fetching the next Codeforces rounds and syncing your reminder timeline."
                        )
                    } else if let errorMessage = contestCenter.errorMessage, contestCenter.upcomingContests.isEmpty {
                        InlineMessageCard(
                            icon: "exclamationmark.triangle.fill",
                            title: "Could not load contests",
                            detail: errorMessage
                        )
                    } else if contestCenter.upcomingContests.isEmpty {
                        InlineMessageCard(
                            icon: "calendar",
                            title: "No upcoming contests",
                            detail: "Codeforces is not showing any scheduled upcoming contests right now."
                        )
                    } else {
                        ForEach(groupedContests) { group in
                            daySection(group.day, contests: group.contests)
                        }
                    }
                }
                .padding(20)
            }
        }
        .navigationTitle("Contest Calendar")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: $webDestination) { destination in
            CodeforcesWebPageView(title: destination.title, url: destination.url)
        }
        .refreshable {
            await contestCenter.refresh(for: sessionStore.currentUser, force: true)
        }
    }

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionTitle(
                title: "Upcoming Codeforces contests",
                subtitle: "Track the next rounds, mark which handles are registered, and keep reminder timing in sync."
            )

            if let nextContest = contestCenter.upcomingContests.first {
                HStack(alignment: .top, spacing: 14) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(nextContest.name)
                            .font(.system(.title3, design: .rounded).weight(.bold))
                            .foregroundStyle(AppTheme.text)

                        HStack(spacing: 8) {
                            InfoBadge(title: nextContest.roundBadge, tint: AppTheme.accent)
                            InfoBadge(title: nextContest.countdownLabel, tint: AppTheme.warm)
                        }

                        Text("Starts \(nextContest.startDateLabel) • Duration \(nextContest.durationLabel)")
                            .font(.system(.subheadline, design: .rounded))
                            .foregroundStyle(AppTheme.mutedText)
                    }

                    Spacer()
                }
            }

            if contestCenter.permissionState != .granted {
                HStack(spacing: 12) {
                    Image(systemName: "bell.badge")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(AppTheme.warning)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Contest reminders are not fully enabled yet.")
                            .font(.system(.subheadline, design: .rounded).weight(.bold))
                            .foregroundStyle(AppTheme.text)

                        Text("Enable notifications so the app can warn you 24 hours, 3 hours, and 1 hour before each contest.")
                            .font(.system(.footnote, design: .rounded))
                            .foregroundStyle(AppTheme.mutedText)
                    }

                    Spacer()

                    if contestCenter.permissionState == .denied {
                        Text("Turn on in Settings")
                            .font(.system(.footnote, design: .rounded).weight(.semibold))
                            .foregroundStyle(AppTheme.warning)
                    } else {
                        Button("Enable") {
                            Task {
                                await contestCenter.requestAuthorizationIfNeeded()
                            }
                        }
                        .buttonStyle(AppSecondaryButtonStyle())
                    }
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(AppTheme.warning.opacity(0.10))
                )
            }
        }
        .appCard()
    }

    private func daySection(_ day: Date, contests: [CodeforcesContest]) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(ContestDayFormatting.sectionHeader.string(from: day))
                .font(.system(.headline, design: .rounded).weight(.bold))
                .foregroundStyle(AppTheme.text)

            ForEach(contests) { contest in
                contestCard(contest)
            }
        }
    }

    private func contestCard(_ contest: CodeforcesContest) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 14) {
                VStack(alignment: .leading, spacing: 10) {
                    Text(contest.name)
                        .font(.system(.headline, design: .rounded).weight(.bold))
                        .foregroundStyle(AppTheme.text)

                    HStack(spacing: 8) {
                        InfoBadge(title: contest.roundBadge, tint: AppTheme.accent)
                        InfoBadge(title: contest.shortStartTimeLabel, tint: AppTheme.accentSecondary)
                        InfoBadge(title: contest.durationLabel, tint: AppTheme.warm)
                    }
                }

                Spacer()

                Text(contest.countdownLabel)
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    .foregroundStyle(AppTheme.accent)
            }

            Text("Registration status is tracked locally in the app because Codeforces does not expose public per-handle pre-registration state through its API.")
                .font(.system(.footnote, design: .rounded))
                .foregroundStyle(AppTheme.mutedText)

            if handles.isEmpty {
                Text("Add Codeforces handles in your profile to track registration reminders.")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(AppTheme.mutedText)
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Tracked handles")
                        .font(.system(.subheadline, design: .rounded).weight(.bold))
                        .foregroundStyle(AppTheme.text)

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                        ForEach(handles) { handle in
                            registrationToggle(for: handle, contest: contest)
                        }
                    }
                }
            }

            HStack(spacing: 10) {
                PracticeActionButton(
                    title: "Open contest",
                    systemImage: "arrow.up.right.square",
                    tint: AppTheme.accent,
                    action: {
                        webDestination = WebDestination(title: contest.name, url: contest.contestURL)
                    }
                )

                PracticeActionButton(
                    title: "Refresh reminders",
                    systemImage: "bell.badge",
                    tint: AppTheme.accentSecondary,
                    action: {
                        Task {
                            await contestCenter.refresh(for: sessionStore.currentUser, force: true)
                        }
                    }
                )
            }
        }
        .appCard()
    }

    private func registrationToggle(for handle: TrackedHandle, contest: CodeforcesContest) -> some View {
        let isRegistered = contestCenter.isHandleRegistered(handle.handle, for: contest, user: sessionStore.currentUser)
        let registrationID = "\(contest.id)::\(handle.handle.lowercased())"

        return Button {
            Task {
                updatingRegistrationID = registrationID
                defer { updatingRegistrationID = nil }

                do {
                    try await sessionStore.setContestRegistration(
                        contestId: contest.id,
                        handle: handle.handle,
                        isRegistered: !isRegistered
                    )
                    await contestCenter.refresh(for: sessionStore.currentUser, force: true)
                } catch {
                    contestCenter.errorMessage = error.localizedDescription
                }
            }
        } label: {
            HStack(spacing: 10) {
                if updatingRegistrationID == registrationID {
                    ProgressView()
                        .tint(isRegistered ? AppTheme.success : AppTheme.warning)
                } else {
                    Image(systemName: isRegistered ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                        .foregroundStyle(isRegistered ? AppTheme.success : AppTheme.warning)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(handle.handle)
                        .font(.system(.subheadline, design: .rounded).weight(.bold))
                        .foregroundStyle(AppTheme.text)

                    Text(isRegistered ? "Marked registered" : "Needs registration")
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(AppTheme.mutedText)
                }

                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill((isRegistered ? AppTheme.success : AppTheme.warning).opacity(0.12))
            )
        }
        .buttonStyle(.plain)
    }
}

private enum ContestDayFormatting {
    static let sectionHeader: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, d MMMM"
        return formatter
    }()
}

#Preview {
    let session = SessionStore(previewUser: UserProfile(
        email: "demo@example.com",
        fullName: "Demo User",
        mobileNumber: "+8801000000000",
        universityName: "Demo University",
        handles: [
            TrackedHandle(handle: "tourist", label: "Main", isPrimary: true),
            TrackedHandle(handle: "Benq", label: "Alt")
        ]
    ))

    return NavigationStack {
        ContestCalendarView()
            .environmentObject(session)
            .environmentObject(ContestCenterStore())
    }
}
