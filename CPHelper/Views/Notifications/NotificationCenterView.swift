import SwiftUI

struct NotificationCenterView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appRouter: AppRouter
    @EnvironmentObject private var contestCenter: ContestCenterStore
    @EnvironmentObject private var sessionStore: SessionStore

    var body: some View {
        ZStack {
            AppBackdrop()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    headerCard

                    if contestCenter.reminderFeed.isEmpty {
                        InlineMessageCard(
                            icon: "bell.slash",
                            title: "No reminders yet",
                            detail: "Once upcoming contests are loaded, your 24h, 3h, and 1h reminders will appear here."
                        )
                    } else {
                        ForEach(contestCenter.reminderFeed) { reminder in
                            reminderCard(reminder)
                        }
                    }
                }
                .padding(20)
            }
        }
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Open calendar") {
                    appRouter.openContestCalendar()
                    dismiss()
                }
            }
        }
        .onAppear {
            contestCenter.markFeedAsRead(for: sessionStore.currentUser)
        }
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionTitle(
                title: "Contest reminders",
                subtitle: "This feed mirrors the reminders the app schedules for upcoming Codeforces contests."
            )

            HStack(spacing: 12) {
                MetricChip(title: "Upcoming", value: "\(contestCenter.upcomingContests.count)")
                MetricChip(title: "Unread", value: "\(contestCenter.unreadCount)")
                MetricChip(title: "Permission", value: contestCenter.permissionState == .granted ? "On" : "Off")
            }

            if contestCenter.permissionState != .granted {
                HStack(spacing: 12) {
                    Image(systemName: "bell.badge")
                        .foregroundStyle(AppTheme.warning)

                    Text("Enable notifications to receive reminders outside the app.")
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(AppTheme.mutedText)

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
            }
        }
        .appCard()
    }

    private func reminderCard(_ reminder: ContestReminderItem) -> some View {
        let isDue = reminder.isDue()

        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: iconName(for: reminder.severity))
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(tint(for: reminder.severity))

                VStack(alignment: .leading, spacing: 8) {
                    Text(reminder.title)
                        .font(.system(.headline, design: .rounded).weight(.bold))
                        .foregroundStyle(AppTheme.text)

                    HStack(spacing: 8) {
                        InfoBadge(title: reminder.contest.roundBadge, tint: AppTheme.accent)
                        InfoBadge(title: isDue ? "Due now" : "Scheduled", tint: tint(for: reminder.severity))
                    }
                }

                Spacer()
            }

            Text(reminder.message)
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(AppTheme.mutedText)

            Text("Reminder time: \(reminder.timeLabel)")
                .font(.system(.footnote, design: .rounded))
                .foregroundStyle(AppTheme.mutedText)
        }
        .appCard()
    }

    private func tint(for severity: ContestReminderSeverity) -> Color {
        switch severity {
        case .neutral:
            return AppTheme.accentSecondary
        case .warning:
            return AppTheme.warning
        case .danger:
            return Color(red: 0.80, green: 0.22, blue: 0.24)
        }
    }

    private func iconName(for severity: ContestReminderSeverity) -> String {
        switch severity {
        case .neutral:
            return "bell.fill"
        case .warning:
            return "exclamationmark.bell.fill"
        case .danger:
            return "flag.fill"
        }
    }
}

#Preview {
    let session = SessionStore(previewUser: UserProfile(
        email: "demo@example.com",
        fullName: "Demo User",
        mobileNumber: "+8801000000000"
    ))

    return NavigationStack {
        NotificationCenterView()
            .environmentObject(AppRouter())
            .environmentObject(session)
            .environmentObject(ContestCenterStore())
    }
}
