import Charts
import SwiftUI

struct WeakAreasView: View {
    @EnvironmentObject private var sessionStore: SessionStore
    @StateObject private var viewModel = WeakAreasViewModel()
    @State private var selectedHandle = ""
    @State private var webDestination: WebDestination?
    @State private var chatbotProblem: CodeforcesProblem?
    @State private var editorialLoadingProblemID: String?
    @State private var alertMessage: String?

    private let chartPalette: [Color] = [
        AppTheme.warning,
        AppTheme.accent,
        AppTheme.accentSecondary,
        AppTheme.warm,
        AppTheme.success
    ]

    private var handles: [TrackedHandle] {
        sessionStore.currentUser?.handles ?? []
    }

    var body: some View {
        ZStack {
            AppBackdrop()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    HandlePickerCard(
                        title: "Weak areas",
                        subtitle: "Review the tags and verdicts that are holding a handle back, then jump into targeted practice.",
                        handles: handles,
                        selectedHandle: $selectedHandle
                    )

                    if viewModel.isLoading {
                        InlineMessageCard(
                            icon: "chart.pie.fill",
                            title: "Analyzing weak areas",
                            detail: "We are comparing topic conversion, verdict mix, and candidate practice problems for this handle."
                        )
                    } else if let errorMessage = viewModel.errorMessage {
                        InlineMessageCard(
                            icon: "exclamationmark.triangle.fill",
                            title: "Could not load weak areas",
                            detail: errorMessage
                        )
                    } else if handles.isEmpty {
                        InlineMessageCard(
                            icon: "person.crop.circle.badge.exclamationmark",
                            title: "Add a handle first",
                            detail: "Weak-area analysis needs at least one Codeforces handle attached to your profile."
                        )
                    } else if let analysis = viewModel.analysis {
                        summaryCard(analysis)
                        weakTopicChart
                        verdictChart(analysis)
                        recommendationSection
                    }
                }
                .padding(20)
            }
        }
        .navigationTitle("Weak Areas")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: $webDestination) { destination in
            CodeforcesWebPageView(title: destination.title, url: destination.url)
        }
        .navigationDestination(item: $chatbotProblem) { problem in
            ChatbotWorkspaceView(problem: problem, handle: selectedHandle)
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
        .onAppear {
            syncSelectedHandle()
        }
        .task(id: selectedHandle) {
            guard !selectedHandle.isEmpty else { return }
            await viewModel.load(for: selectedHandle)
        }
    }

    private func summaryCard(_ analysis: HandleAnalysis) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionTitle(
                title: "Why these topics are highlighted",
                subtitle: "Weak topics are weighted by attempt volume and low acceptance, so noisy one-off misses do not dominate."
            )

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                MetricChip(title: "Current rating", value: analysis.summary.currentRating.map(String.init) ?? "Unrated")
                MetricChip(title: "Overall AC", value: NumberFormatting.percentage(analysis.summary.overallAcceptanceRate))
                MetricChip(title: "Weak tags", value: "\(viewModel.weakTopics.count)")
                MetricChip(title: "Tracked handle", value: "@\(selectedHandle)")
            }

            if let weakest = viewModel.weakTopics.first {
                Text("Right now the sharpest drag comes from \(weakest.topic.tag), where conversion sits at \(NumberFormatting.percentage(weakest.topic.acceptanceRate)).")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(AppTheme.mutedText)
            }
        }
        .appCard()
    }

    private var weakTopicChart: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionTitle(
                title: "Weak topic pie",
                subtitle: "Bigger slices mean more repeated misses around a tag."
            )

            if viewModel.weakTopics.isEmpty {
                Text("There is not enough topic history yet to isolate a weak area.")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(AppTheme.mutedText)
            } else {
                Chart(Array(viewModel.weakTopics.enumerated()), id: \.element.id) { index, weakTopic in
                    SectorMark(
                        angle: .value("Weakness", max(weakTopic.weaknessScore, 0.01)),
                        innerRadius: .ratio(0.56),
                        angularInset: 2
                    )
                    .foregroundStyle(chartPalette[index % chartPalette.count])
                }
                .frame(height: 250)

                VStack(spacing: 12) {
                    ForEach(Array(viewModel.weakTopics.enumerated()), id: \.element.id) { index, weakTopic in
                        ChartLegendRow(
                            title: weakTopic.topic.tag,
                            detail: weakTopic.note,
                            tint: chartPalette[index % chartPalette.count]
                        )
                    }
                }
            }
        }
        .appCard()
    }

    private func verdictChart(_ analysis: HandleAnalysis) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionTitle(
                title: "Verdict pie",
                subtitle: "This shows whether misses mostly come from wrong answers, limits, or compilation issues."
            )

            if analysis.verdicts.isEmpty {
                Text("No verdict data available.")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(AppTheme.mutedText)
            } else {
                Chart(analysis.verdicts) { slice in
                    SectorMark(
                        angle: .value("Count", slice.count),
                        innerRadius: .ratio(0.56),
                        angularInset: 2
                    )
                    .foregroundStyle(slice.verdict.tint)
                }
                .frame(height: 250)

                VStack(spacing: 12) {
                    ForEach(analysis.verdicts) { slice in
                        ChartLegendRow(
                            title: slice.verdict.title,
                            detail: "\(slice.count) submissions | \(NumberFormatting.percentage(slice.share))",
                            tint: slice.verdict.tint
                        )
                    }
                }
            }
        }
        .appCard()
    }

    private var recommendationSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionTitle(
                title: "Targeted practice",
                subtitle: "These problems stay near the handle's band but push directly on the weakest tags."
            )

            if viewModel.recommendations.isEmpty {
                Text("No targeted problem suggestions are ready yet. More attempts on tagged problems will make this sharper.")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(AppTheme.mutedText)
            } else {
                ForEach(viewModel.recommendations) { recommendation in
                    VStack(alignment: .leading, spacing: 14) {
                        HStack(spacing: 8) {
                            Text(recommendation.weakTopic.topic.tag)
                                .font(.system(.headline, design: .rounded).weight(.bold))
                                .foregroundStyle(AppTheme.text)

                            InfoBadge(
                                title: recommendation.weakTopic.note,
                                tint: AppTheme.warning
                            )
                        }

                        ForEach(recommendation.problems) { problem in
                            let alreadySaved = isInTodo(problem, handle: selectedHandle)

                            CodeforcesProblemCard(
                                problem: problem,
                                subtitle: "Fix \(recommendation.weakTopic.topic.tag)",
                                isInTodo: alreadySaved,
                                todoButtonTitle: alreadySaved ? "Saved" : "Add to Todo",
                                todoButtonTint: alreadySaved ? AppTheme.success : AppTheme.accent,
                                isTodoActionDisabled: alreadySaved,
                                isEditorialLoading: editorialLoadingProblemID == problem.id,
                                footerNote: "Chosen because it stays near your practice band and matches \(recommendation.weakTopic.topic.tag).",
                                onOpenProblem: {
                                    webDestination = WebDestination(title: problem.name, url: problem.problemURL)
                                },
                                onTodoAction: {
                                    guard !alreadySaved else { return }
                                    Task {
                                        do {
                                            try await sessionStore.addTodoProblem(problem, for: selectedHandle)
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
                    }
                }
            }
        }
        .appCard()
    }

    private func syncSelectedHandle() {
        if selectedHandle.isEmpty {
            selectedHandle = sessionStore.currentUser?.primaryHandle ?? handles.first?.handle ?? ""
            return
        }

        if !handles.contains(where: { $0.handle == selectedHandle }) {
            selectedHandle = sessionStore.currentUser?.primaryHandle ?? handles.first?.handle ?? ""
        }
    }

    private func isInTodo(_ problem: CodeforcesProblem, handle: String) -> Bool {
        sessionStore.currentUser?.todoProblems.contains(where: {
            $0.handle.caseInsensitiveCompare(handle) == .orderedSame
                && $0.contestId == problem.contestId
                && $0.index == problem.index
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
        handles: [
            TrackedHandle(handle: "tourist", label: "Main", isPrimary: true),
            TrackedHandle(handle: "Benq", label: "Alt")
        ]
    ))

    return NavigationStack {
        WeakAreasView()
            .environmentObject(session)
    }
}
