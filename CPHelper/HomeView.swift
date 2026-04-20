import Charts
import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var appRouter: AppRouter
    @EnvironmentObject private var contestCenter: ContestCenterStore
    @EnvironmentObject private var sessionStore: SessionStore

    @State private var primaryHandleInput = ""
    @State private var primaryAnalysis: HandleAnalysis?
    @State private var isLoadingAnalysis = false
    @State private var analysisError: String?

    var body: some View {
        ZStack {
            AppBackdrop()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    headerCard
                    primarySection
                    nextContestSection
                }
                .padding(20)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Text("Home")
                    .font(.system(.headline, design: .rounded).weight(.bold))
                    .foregroundStyle(AppTheme.text)
            }

            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    appRouter.openProfile()
                } label: {
                    AvatarView(
                        title: sessionStore.currentUser?.initials ?? "U",
                        imageURL: sessionStore.currentUser?.profileImageURL,
                        size: 38
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .task(id: sessionStore.currentUser?.primaryHandle ?? "") {
            await loadPrimaryAnalysis()
        }
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(sessionStore.currentUser?.fullName ?? "Welcome")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundStyle(AppTheme.text)

            HStack(spacing: 10) {
                MetricChip(title: "Primary", value: sessionStore.currentUser?.primaryHandle ?? "Not set")
                MetricChip(title: "Friends", value: "\(sessionStore.currentUser?.friends.count ?? 0)")
                MetricChip(title: "Todo", value: "\(sessionStore.currentUser?.todoProblems.count ?? 0)")
            }
        }
    }

    @ViewBuilder
    private var primarySection: some View {
        if let primaryHandle = sessionStore.currentUser?.primaryHandle, !primaryHandle.isEmpty {
            primaryOverviewCard(handle: primaryHandle)
        } else {
            primaryHandleSetupCard
        }
    }

    private func primaryOverviewCard(handle: String) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 14) {
                AvatarView(
                    title: handle,
                    imageURL: primaryAnalysis?.summary.avatarURL,
                    size: 64
                )

                VStack(alignment: .leading, spacing: 6) {
                    Text("Primary profile")
                        .font(.system(.caption, design: .rounded).weight(.bold))
                        .foregroundStyle(AppTheme.mutedText)

                    Text("@\(handle)")
                        .font(.system(.title3, design: .rounded).weight(.bold))
                        .foregroundStyle(AppTheme.text)

                    Text(primaryAnalysis?.summary.firstActiveDate.map { DateFormatting.mediumDate.string(from: $0) } ?? "Loading...")
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(AppTheme.mutedText)
                }

                Spacer()

                Button("More") {
                    appRouter.openHandleAnalysis(handle)
                }
                .buttonStyle(AppSecondaryButtonStyle())
            }

            if let analysis = primaryAnalysis {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    statCard(title: "Current", value: analysis.summary.currentRating.map(String.init) ?? "Unrated")
                    statCard(title: "Max", value: analysis.summary.maxRating.map(String.init) ?? "Unrated")
                    statCard(title: "Solved", value: NumberFormatting.compact(analysis.summary.solvedCount))
                    statCard(title: "AC", value: NumberFormatting.percentage(analysis.summary.overallAcceptanceRate))
                }

                if !analysis.ratingHistory.isEmpty {
                    Chart(analysis.ratingHistory.suffix(10)) { point in
                        LineMark(
                            x: .value("Date", point.date),
                            y: .value("Rating", point.newRating)
                        )
                        .foregroundStyle(AppTheme.accent.gradient)
                        .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round))
                    }
                    .frame(height: 130)
                }
            } else if isLoadingAnalysis {
                InlineMessageCard(
                    icon: "chart.line.uptrend.xyaxis",
                    title: "Loading primary profile",
                    detail: "Fetching Codeforces data."
                )
            } else if let analysisError {
                InlineMessageCard(
                    icon: "exclamationmark.triangle.fill",
                    title: "Could not load profile",
                    detail: analysisError
                )
            }
        }
        .appCard()
    }

    private var primaryHandleSetupCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionTitle(title: "Primary Handle", subtitle: "Set once")

            TextField("tourist", text: $primaryHandleInput)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .appInputField()

            Button("Save Primary Handle") {
                Task {
                    do {
                        analysisError = nil
                        try await sessionStore.setPrimaryHandle(primaryHandleInput)
                        primaryHandleInput = ""
                    } catch {
                        analysisError = error.localizedDescription
                    }
                }
            }
            .buttonStyle(AppPrimaryButtonStyle())

            if let analysisError {
                Text(analysisError)
                    .font(.system(.footnote, design: .rounded))
                    .foregroundStyle(Color(red: 0.76, green: 0.21, blue: 0.22))
            }
        }
        .appCard()
    }

    private var nextContestSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionTitle(title: "Next Contest", subtitle: "Upcoming")

            if let nextContest = contestCenter.upcomingContests.first {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(nextContest.name)
                                .font(.system(.headline, design: .rounded).weight(.bold))
                                .foregroundStyle(AppTheme.text)

                            HStack(spacing: 8) {
                                InfoBadge(title: nextContest.roundBadge, tint: AppTheme.accent)
                                InfoBadge(title: nextContest.countdownLabel, tint: AppTheme.warm)
                            }
                        }

                        Spacer()
                    }

                    Text(nextContest.startDateLabel)
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(AppTheme.mutedText)

                    Text(contestCenter.registrationSummary(for: nextContest, user: sessionStore.currentUser))
                        .font(.system(.footnote, design: .rounded))
                        .foregroundStyle(AppTheme.mutedText)

                    Button("Open Calendar") {
                        appRouter.openContestCalendar()
                    }
                    .buttonStyle(AppPrimaryButtonStyle())
                }
                .appCard()
            } else if contestCenter.isLoading {
                InlineMessageCard(
                    icon: "calendar.badge.clock",
                    title: "Loading contest",
                    detail: "Fetching Codeforces schedule."
                )
            } else {
                InlineMessageCard(
                    icon: "calendar",
                    title: "No contest found",
                    detail: "Nothing upcoming right now."
                )
            }
        }
    }

    private func loadPrimaryAnalysis() async {
        guard let handle = sessionStore.currentUser?.primaryHandle, !handle.isEmpty else {
            primaryAnalysis = nil
            analysisError = nil
            return
        }

        primaryAnalysis = nil
        isLoadingAnalysis = true
        defer { isLoadingAnalysis = false }

        do {
            primaryAnalysis = try await CodeforcesAnalysisService.shared.loadAnalysis(for: handle)
            analysisError = nil
        } catch {
            primaryAnalysis = nil
            analysisError = error.localizedDescription
        }
    }

    private func statCard(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.system(.headline, design: .rounded).weight(.bold))
                .foregroundStyle(AppTheme.text)

            Text(title)
                .font(.system(.caption, design: .rounded).weight(.medium))
                .foregroundStyle(AppTheme.mutedText)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(AppTheme.background)
        )
    }
}

#Preview {
    let session = SessionStore(previewUser: UserProfile(
        email: "demo@example.com",
        fullName: "Demo User",
        mobileNumber: "+8801000000000",
        universityName: "Demo University",
        primaryHandle: "tourist",
        friends: [
            FriendProfile(handle: "Benq", nickname: "Ben")
        ]
    ))

    return NavigationStack {
        HomeView()
            .environmentObject(AppRouter())
            .environmentObject(ContestCenterStore())
            .environmentObject(session)
    }
}
