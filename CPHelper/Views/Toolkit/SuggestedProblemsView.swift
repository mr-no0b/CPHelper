import SwiftUI

struct SuggestedProblemsView: View {
    @EnvironmentObject private var sessionStore: SessionStore
    @StateObject private var viewModel = SuggestedProblemsViewModel()
    @State private var selectedHandle = ""
    @State private var webDestination: WebDestination?
    @State private var chatbotProblem: CodeforcesProblem?
    @State private var editorialLoadingProblemID: String?
    @State private var alertMessage: String?

    private var handles: [TrackedHandle] {
        sessionStore.currentUser?.handles ?? []
    }

    var body: some View {
        ZStack {
            AppBackdrop()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    HandlePickerCard(
                        title: "Suggested problems",
                        subtitle: "Pick a handle and we will suggest Codeforces problems around its current and peak rating.",
                        handles: handles,
                        selectedHandle: $selectedHandle
                    )

                    if let analysis = viewModel.analysis {
                        summaryCard(analysis)
                    }

                    if viewModel.isLoading {
                        InlineMessageCard(
                            icon: "sparkles",
                            title: "Building your practice queue",
                            detail: "Fetching live Codeforces data and selecting problems near the right difficulty band."
                        )
                    } else if let errorMessage = viewModel.errorMessage {
                        InlineMessageCard(
                            icon: "exclamationmark.triangle.fill",
                            title: "Could not load suggestions",
                            detail: errorMessage
                        )
                    } else if handles.isEmpty {
                        InlineMessageCard(
                            icon: "person.crop.circle.badge.exclamationmark",
                            title: "Add a handle first",
                            detail: "Open the Profile tab, add one or more Codeforces handles, and this screen will tailor suggestions for them."
                        )
                    } else if viewModel.suggestions.isEmpty {
                        InlineMessageCard(
                            icon: "tray.fill",
                            title: "No suggestions yet",
                            detail: "We could not find fresh unsolved problems in the current band. Try refreshing after you add more activity or handles."
                        )
                    } else {
                        problemsSection
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
                title: "Recommendation window",
                subtitle: "These suggestions balance current rating with historical ceiling so practice stays challenging but realistic."
            )

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                MetricChip(
                    title: "Current rating",
                    value: analysis.summary.currentRating.map(String.init) ?? "Unrated"
                )
                MetricChip(
                    title: "Max rating",
                    value: analysis.summary.maxRating.map(String.init) ?? "Unrated"
                )
                MetricChip(title: "Suggested band", value: viewModel.ratingBandLabel)
                MetricChip(title: "Todo for handle", value: "\(todoCount(for: selectedHandle))")
            }

            Text(viewModel.recommendationSummary)
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(AppTheme.mutedText)
        }
        .appCard()
    }

    private var problemsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionTitle(
                title: "Fresh picks",
                subtitle: "Tap a problem to read the statement, save it to the todo list, jump to the editorial, or carry it into the chatbot."
            )

            ForEach(viewModel.suggestions) { problem in
                let alreadySaved = isInTodo(problem, handle: selectedHandle)

                CodeforcesProblemCard(
                    problem: problem,
                    subtitle: "Suggested for @\(selectedHandle)",
                    isInTodo: alreadySaved,
                    todoButtonTitle: alreadySaved ? "Saved" : "Add to Todo",
                    todoButtonTint: alreadySaved ? AppTheme.success : AppTheme.accent,
                    isTodoActionDisabled: alreadySaved,
                    isEditorialLoading: editorialLoadingProblemID == problem.id,
                    footerNote: problem.solvedCount.map { "\($0.formatted(.number.notation(.compactName))) users solved this one." },
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

    private func todoCount(for handle: String) -> Int {
        sessionStore.currentUser?.todoProblems.filter {
            $0.handle.caseInsensitiveCompare(handle) == .orderedSame
        }.count ?? 0
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
        SuggestedProblemsView()
            .environmentObject(session)
    }
}
