import SwiftUI

struct ContestCalendarView: View {
    @EnvironmentObject private var contestCenter: ContestCenterStore
    @EnvironmentObject private var sessionStore: SessionStore

    @State private var webDestination: WebDestination?
    @State private var updatingContestID: Int?

    private var primaryHandle: String? {
        sessionStore.currentUser?.primaryHandle
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
                VStack(alignment: .leading, spacing: 18) {
                    heroCard

                    if contestCenter.isLoading && contestCenter.upcomingContests.isEmpty {
                        InlineMessageCard(
                            icon: "calendar.badge.clock",
                            title: "Loading contests",
                            detail: "Fetching schedule."
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
                            detail: "Nothing scheduled right now."
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
        VStack(alignment: .leading, spacing: 14) {
            SectionTitle(title: "Contest Calendar", subtitle: "Upcoming rounds")

            if let nextContest = contestCenter.upcomingContests.first {
                Text(nextContest.name)
                    .font(.system(.title3, design: .rounded).weight(.bold))
                    .foregroundStyle(AppTheme.text)

                HStack(spacing: 8) {
                    InfoBadge(title: nextContest.roundBadge, tint: AppTheme.accent)
                    InfoBadge(title: nextContest.countdownLabel, tint: AppTheme.warm)
                    InfoBadge(title: nextContest.durationLabel, tint: AppTheme.accentSecondary)
                }
            }

            if contestCenter.permissionState != .granted {
                HStack(spacing: 12) {
                    Image(systemName: "bell.badge")
                        .foregroundStyle(AppTheme.warning)

                    Text(contestCenter.permissionState == .denied ? "Notifications are off in Settings." : "Enable contest reminders.")
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(AppTheme.mutedText)

                    Spacer()

                    if contestCenter.permissionState == .unknown {
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

    private func daySection(_ day: Date, contests: [CodeforcesContest]) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(ContestDayFormatting.sectionHeader.string(from: day))
                .font(.system(.headline, design: .rounded).weight(.bold))
                .foregroundStyle(AppTheme.text)

            ForEach(contests) { contest in
                contestCard(contest)
            }
        }
    }

    private func contestCard(_ contest: CodeforcesContest) -> some View {
        let isRegistered = contestCenter.isRegistered(for: contest, user: sessionStore.currentUser)

        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(contest.name)
                        .font(.system(.headline, design: .rounded).weight(.bold))
                        .foregroundStyle(AppTheme.text)

                    HStack(spacing: 8) {
                        InfoBadge(title: contest.shortStartTimeLabel, tint: AppTheme.accent)
                        InfoBadge(title: contest.countdownLabel, tint: AppTheme.warm)
                    }
                }

                Spacer()
            }

            Text(contestCenter.registrationSummary(for: contest, user: sessionStore.currentUser))
                .font(.system(.footnote, design: .rounded))
                .foregroundStyle(AppTheme.mutedText)

            if let primaryHandle, !primaryHandle.isEmpty {
                Button {
                    Task {
                        updatingContestID = contest.id
                        defer { updatingContestID = nil }

                        do {
                            try await sessionStore.setContestRegistration(
                                contestId: contest.id,
                                handle: primaryHandle,
                                isRegistered: !isRegistered
                            )
                            await contestCenter.refresh(for: sessionStore.currentUser, force: true)
                        } catch {
                            contestCenter.errorMessage = error.localizedDescription
                        }
                    }
                } label: {
                    HStack(spacing: 10) {
                        if updatingContestID == contest.id {
                            ProgressView().tint(isRegistered ? AppTheme.success : AppTheme.warning)
                        } else {
                            Image(systemName: isRegistered ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                                .foregroundStyle(isRegistered ? AppTheme.success : AppTheme.warning)
                        }

                        Text(isRegistered ? "Marked registered" : "Mark registered")
                            .font(.system(.subheadline, design: .rounded).weight(.semibold))
                            .foregroundStyle(AppTheme.text)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill((isRegistered ? AppTheme.success : AppTheme.warning).opacity(0.12))
                    )
                }
                .buttonStyle(.plain)
            } else {
                Text("Add your primary handle in Profile to track registration.")
                    .font(.system(.footnote, design: .rounded))
                    .foregroundStyle(AppTheme.mutedText)
            }

            HStack(spacing: 10) {
                PracticeActionButton(
                    title: "Open Contest",
                    systemImage: "arrow.up.right.square",
                    tint: AppTheme.accent,
                    action: {
                        webDestination = WebDestination(title: contest.name, url: contest.contestURL)
                    }
                )

                PracticeActionButton(
                    title: "Refresh",
                    systemImage: "arrow.clockwise",
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
        primaryHandle: "tourist"
    ))

    return NavigationStack {
        ContestCalendarView()
            .environmentObject(session)
            .environmentObject(ContestCenterStore())
    }
}
