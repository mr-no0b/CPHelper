import Charts
import SwiftUI

struct SuggestedProblemsView: View {
    @EnvironmentObject private var sessionStore: SessionStore
    @StateObject private var viewModel = SuggestedProblemsViewModel()

    @State private var webDestination: WebDestination?
    @State private var chatbotProblem: CodeforcesProblem?
    @State private var editorialLoadingProblemID: String?
    @State private var alertMessage: String?

    private let chartPalette: [Color] = [
        AppTheme.accent,
        AppTheme.warm,
        AppTheme.accentSecondary,
        AppTheme.warning,
        AppTheme.success
    ]

    private var primaryHandle: String {
        sessionStore.currentUser?.primaryHandle ?? ""
    }

    var body: some View {
        ZStack {
            AppBackdrop()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    headerCard

                    if viewModel.isLoading {
                        InlineMessageCard(
                            icon: "sparkles",
                            title: "Loading suggestions",
                            detail: "Fetching analysis and problemset."
                        )
                    } else if let errorMessage = viewModel.errorMessage {
                        InlineMessageCard(
                            icon: "exclamationmark.triangle.fill",
                            title: "Could not load suggestions",
                            detail: errorMessage
                        )
                    } else if primaryHandle.isEmpty {
                        InlineMessageCard(
                            icon: "person.crop.circle.badge.exclamationmark",
                            title: "Primary handle missing",
                            detail: "Add your primary handle in Profile."
                        )
                    } else if let analysis = viewModel.analysis {
                        summaryCard(analysis)
                        ratingMixCard
                        weakTagsCard
                        ratingSuggestionsSection
                        weakRecommendationsSection
                    }
                }
                .padding(20)
            }
        }
        .navigationTitle("Suggested Problems")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: $webDestination) { destination in
            CodeforcesWebPageView(title: destination.title, url: destination.url)
        }
        .navigationDestination(item: $chatbotProblem) { problem in
            ChatbotWorkspaceView(problem: problem, handle: primaryHandle)
        }
        .alert(
            "Notice",
            isPresented: Binding(
                get: { alertMessage != nil },
                set: { if !$0 { alertMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(alertMessage ?? "")
        }
        .task(id: primaryHandle) {
            guard !primaryHandle.isEmpty else { return }
            await viewModel.load(for: primaryHandle)
        }
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionTitle(title: "Suggested Problems", subtitle: "Primary handle")
            if primaryHandle.isEmpty {
                Text("No primary handle yet.")
                    .font(.system(.headline, design: .rounded).weight(.bold))
                    .foregroundStyle(AppTheme.text)
            } else {
                CodeforcesHandleView(
                    handle: primaryHandle,
                    rating: viewModel.analysis?.summary.currentRating,
                    font: .system(.headline, design: .rounded).weight(.bold)
                )
            }
        }
        .appCard()
    }

    private func summaryCard(_ analysis: HandleAnalysis) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionTitle(title: "Rating Window", subtitle: viewModel.ratingBandLabel)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                metric(title: "Current", value: analysis.summary.currentRating.map(String.init) ?? "Unrated")
                metric(title: "Max", value: analysis.summary.maxRating.map(String.init) ?? "Unrated")
                metric(title: "Solved", value: NumberFormatting.compact(analysis.summary.solvedCount))
                metric(title: "Weak tags", value: "\(viewModel.weakTopics.count)")
            }
        }
        .appCard()
    }

    private var ratingMixCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionTitle(title: "Rating Mix", subtitle: "By peak rating")

            if viewModel.ratingMix.isEmpty {
                Text("No suggestions yet.")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(AppTheme.mutedText)
            } else {
                Chart(Array(viewModel.ratingMix.enumerated()), id: \.element.id) { index, slice in
                    SectorMark(
                        angle: .value("Count", slice.count),
                        innerRadius: .ratio(0.56),
                        angularInset: 2
                    )
                    .foregroundStyle(chartPalette[index % chartPalette.count])
                }
                .frame(height: 240)

                VStack(spacing: 10) {
                    ForEach(Array(viewModel.ratingMix.enumerated()), id: \.element.id) { index, slice in
                        ChartLegendRow(
                            title: slice.title,
                            detail: "\(slice.count) problems",
                            tint: chartPalette[index % chartPalette.count]
                        )
                    }
                }
            }
        }
        .appCard()
    }

    private var weakTagsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionTitle(title: "Weak Tags", subtitle: "Tag analysis")

            if viewModel.weakTopics.isEmpty {
                Text("Not enough tagged attempts yet.")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(AppTheme.mutedText)
            } else {
                Chart(Array(viewModel.weakTopics.enumerated()), id: \.element.id) { index, topic in
                    SectorMark(
                        angle: .value("Weakness", max(topic.weaknessScore, 0.01)),
                        innerRadius: .ratio(0.56),
                        angularInset: 2
                    )
                    .foregroundStyle(chartPalette[index % chartPalette.count])
                }
                .frame(height: 240)

                VStack(spacing: 10) {
                    ForEach(Array(viewModel.weakTopics.enumerated()), id: \.element.id) { index, topic in
                        ChartLegendRow(
                            title: topic.topic.tag,
                            detail: topic.note,
                            tint: chartPalette[index % chartPalette.count]
                        )
                    }
                }
            }
        }
        .appCard()
    }

    private var ratingSuggestionsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionTitle(title: "Suggestions By Rating", subtitle: "Peak-based")

            if viewModel.ratingSuggestions.isEmpty {
                Text("No suggestions ready.")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(AppTheme.mutedText)
            } else {
                ForEach(viewModel.ratingSuggestions) { problem in
                    problemCard(problem, subtitle: "By rating")
                }
            }
        }
    }

    private var weakRecommendationsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionTitle(title: "Suggestions By Weak Tags", subtitle: "Fix weak areas")

            if viewModel.weakRecommendations.isEmpty {
                Text("No weak-tag suggestions ready.")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(AppTheme.mutedText)
            } else {
                ForEach(viewModel.weakRecommendations) { recommendation in
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 8) {
                            Text(recommendation.weakTopic.topic.tag)
                                .font(.system(.headline, design: .rounded).weight(.bold))
                                .foregroundStyle(AppTheme.text)

                            InfoBadge(title: recommendation.weakTopic.note, tint: AppTheme.warning)
                        }

                        ForEach(recommendation.problems) { problem in
                            problemCard(problem, subtitle: recommendation.weakTopic.topic.tag)
                        }
                    }
                    .appCard()
                }
            }
        }
    }

    private func problemCard(_ problem: CodeforcesProblem, subtitle: String) -> some View {
        let alreadySaved = isInTodo(problem)

        return CodeforcesProblemCard(
            problem: problem,
            subtitle: subtitle,
            isInTodo: alreadySaved,
            todoButtonTitle: alreadySaved ? "Saved" : "Add ToDo",
            todoButtonTint: alreadySaved ? AppTheme.success : AppTheme.accent,
            isTodoActionDisabled: alreadySaved,
            isEditorialLoading: editorialLoadingProblemID == problem.id,
            footerNote: problem.solvedCount.map { "\($0.formatted(.number.notation(.compactName))) solves" },
            onOpenProblem: {
                webDestination = WebDestination(title: problem.name, url: problem.problemURL)
            },
            onTodoAction: {
                guard !alreadySaved else { return }
                Task {
                    do {
                        try await sessionStore.addTodoProblem(problem, for: primaryHandle)
                    } catch {
                        alertMessage = error.localizedDescription
                    }
                }
            },
            onAskChatbot: {
                chatbotProblem = problem
            },
            onOpenEditorial: {
                Task {
                    await openEditorial(for: problem)
                }
            }
        )
    }

    private func metric(title: String, value: String) -> some View {
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

    private func isInTodo(_ problem: CodeforcesProblem) -> Bool {
        sessionStore.currentUser?.todoProblems.contains(where: {
            $0.contestId == problem.contestId && $0.index == problem.index
        }) ?? false
    }

    private func openEditorial(for problem: CodeforcesProblem) async {
        editorialLoadingProblemID = problem.id
        defer { editorialLoadingProblemID = nil }

        do {
            if let editorialURL = try await CodeforcesEditorialService.shared.editorialURL(for: problem) {
                webDestination = WebDestination(title: "Editorial", url: editorialURL)
            } else {
                alertMessage = "This problem does not expose a tutorial link on Codeforces yet."
            }
        } catch {
            alertMessage = error.localizedDescription
        }
    }
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
        SuggestedProblemsView()
            .environmentObject(session)
    }
}
