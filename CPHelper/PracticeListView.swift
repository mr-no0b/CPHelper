import SwiftUI

struct PracticeListView: View {
    @EnvironmentObject private var sessionStore: SessionStore
    @State private var webDestination: WebDestination?
    @State private var chatbotProblem: CodeforcesProblem?
    @State private var chatbotHandle = ""
    @State private var editorialLoadingID: String?
    @State private var alertMessage: String?
    @State private var problemLinkInput = ""
    @State private var isAddingLink = false

    private var groupedTodos: [(handle: String, items: [TodoProblem])] {
        let todoProblems = sessionStore.currentUser?.todoProblems.sorted { lhs, rhs in
            if lhs.handle.caseInsensitiveCompare(rhs.handle) == .orderedSame {
                return lhs.addedAt > rhs.addedAt
            }
            return lhs.handle.localizedCaseInsensitiveCompare(rhs.handle) == .orderedAscending
        } ?? []

        let grouped = Dictionary(grouping: todoProblems, by: \.handle)
        return grouped.keys.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }.map { handle in
            (handle, grouped[handle] ?? [])
        }
    }

    var body: some View {
        ZStack {
            AppBackdrop()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    addLinkCard

                    if groupedTodos.isEmpty {
                        emptyStateView
                    } else {
                        ForEach(groupedTodos, id: \.handle) { group in
                            VStack(alignment: .leading, spacing: 12) {
                                if group.handle.isEmpty {
                                    Text("Saved Problems")
                                        .font(.system(.headline, design: .rounded).weight(.bold))
                                        .foregroundStyle(AppTheme.text)
                                } else {
                                    CodeforcesHandleView(
                                        handle: group.handle,
                                        font: .system(.headline, design: .rounded).weight(.bold)
                                    )
                                }

                                ForEach(group.items) { todo in
                                    CodeforcesProblemCard(
                                        problem: todo.asCatalogProblem,
                                        subtitle: todo.handle.isEmpty ? "Saved" : "Saved for \(todo.handle)",
                                        isInTodo: true,
                                        todoButtonTitle: "Remove",
                                        todoButtonTint: Color(red: 0.79, green: 0.22, blue: 0.23),
                                        todoSystemImage: "trash.fill",
                                        isEditorialLoading: editorialLoadingID == todo.id,
                                        footerNote: DateFormatting.mediumDate.string(from: todo.addedAt),
                                        onOpenProblem: {
                                            webDestination = WebDestination(title: todo.name, url: todo.problemURL)
                                        },
                                        onTodoAction: {
                                            Task {
                                                do {
                                                    try await sessionStore.removeTodoProblem(todoID: todo.id)
                                                } catch {
                                                    alertMessage = error.localizedDescription
                                                }
                                            }
                                        },
                                        onAskChatbot: {
                                            chatbotHandle = todo.handle
                                            chatbotProblem = todo.asCatalogProblem
                                        },
                                        onOpenEditorial: {
                                            Task {
                                                await openEditorial(for: todo)
                                            }
                                        }
                                    )
                                }
                            }
                        }
                    }
                }
                .padding(20)
            }
        }
        .navigationTitle("ToDo")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: $webDestination) { destination in
            CodeforcesWebPageView(title: destination.title, url: destination.url)
        }
        .navigationDestination(item: $chatbotProblem) { problem in
            ChatbotWorkspaceView(problem: problem, handle: chatbotHandle)
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
    }

    private var addLinkCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionTitle(title: "Add By Link", subtitle: "Codeforces problem URL")

            TextField("https://codeforces.com/problemset/problem/4/A", text: $problemLinkInput)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .appInputField()

            Button {
                Task {
                    await addProblemLink()
                }
            } label: {
                if isAddingLink {
                    ProgressView().tint(.white)
                } else {
                    Text("Add Problem")
                }
            }
            .buttonStyle(AppPrimaryButtonStyle())
            .disabled(isAddingLink)
        }
        .appCard()
    }

    private var emptyStateView: some View {
        InlineMessageCard(
            icon: "checklist.checked",
            title: "No saved problems",
            detail: "Add from suggestions or paste a problem link."
        )
    }

    private func addProblemLink() async {
        let trimmed = problemLinkInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            alertMessage = "Paste a problem link."
            return
        }

        isAddingLink = true
        defer { isAddingLink = false }

        do {
            try await sessionStore.addTodoProblem(from: trimmed)
            problemLinkInput = ""
        } catch {
            alertMessage = error.localizedDescription
        }
    }

    private func openEditorial(for todo: TodoProblem) async {
        editorialLoadingID = todo.id
        defer { editorialLoadingID = nil }

        do {
            if let editorialURL = try await CodeforcesEditorialService.shared.editorialURL(for: todo.asCatalogProblem) {
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
    let todoProblems = [
        TodoProblem(
            handle: "tourist",
            problem: CodeforcesProblem(
                contestId: 231,
                index: "A",
                name: "Team",
                rating: 800,
                tags: ["brute force", "greedy"],
                solvedCount: 100000
            )
        )
    ]

    let session = SessionStore(previewUser: UserProfile(
        email: "demo@example.com",
        fullName: "Demo User",
        mobileNumber: "+8801000000000",
        universityName: "Demo University",
        primaryHandle: "tourist",
        todoProblems: todoProblems
    ))

    NavigationStack {
        PracticeListView()
            .environmentObject(session)
    }
}
