import SwiftUI

struct ChatbotWorkspaceView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appRouter: AppRouter
    @EnvironmentObject private var sessionStore: SessionStore
    @EnvironmentObject private var tutorialLibrary: TutorialLibraryStore

    let problem: CodeforcesProblem?
    let handle: String?

    @StateObject private var viewModel: ChatbotViewModel

    init(problem: CodeforcesProblem? = nil, handle: String? = nil) {
        self.problem = problem
        self.handle = handle
        _viewModel = StateObject(
            wrappedValue: ChatbotViewModel(problem: problem, preferredHandle: handle)
        )
    }

    var body: some View {
        ZStack {
            AppBackdrop()

            VStack(spacing: 0) {
                if let problem {
                    attachedProblemStrip(problem)
                }

                messagePanel
                composerPanel
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 12)
        }
        .navigationTitle("CP Coach")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await tutorialLibrary.loadIfNeeded()
            await viewModel.prepare(user: sessionStore.currentUser)
        }
    }

    private func attachedProblemStrip(_ problem: CodeforcesProblem) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "paperclip.circle.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(AppTheme.accent)

            VStack(alignment: .leading, spacing: 8) {
                Text("\(problem.displayID) \(problem.name)")
                    .font(.system(.subheadline, design: .rounded).weight(.bold))
                    .foregroundStyle(AppTheme.text)
                    .lineLimit(2)

                HStack(spacing: 8) {
                    if let rating = problem.rating {
                        InfoBadge(title: "\(rating)", tint: AppTheme.accent)
                    }

                    if let firstTag = problem.tags.first {
                        InfoBadge(title: firstTag, tint: AppTheme.accentSecondary)
                    }
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.94))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(AppTheme.cardBorder, lineWidth: 1)
                )
        )
        .padding(.bottom, 12)
    }

    private var messagePanel: some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 12) {
                    ForEach(viewModel.messages) { message in
                        MessageBubble(message: message)
                            .id(message.id)
                    }

                    if viewModel.isSending {
                        typingIndicator
                            .id("typing-indicator")
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 0)
                .padding(.vertical, 4)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: viewModel.messages.count) { _ in
                scrollToBottom(using: proxy)
            }
            .onChange(of: viewModel.isSending) { _ in
                scrollToBottom(using: proxy)
            }
        }
    }

    private var composerPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .font(.system(.footnote, design: .rounded))
                    .foregroundStyle(Color(red: 0.78, green: 0.22, blue: 0.24))
            }

            HStack(alignment: .bottom, spacing: 12) {
                TextField(
                    problem == nil
                        ? "Ask about handles, DSA, roadmaps, tutorials, or strategy..."
                        : "Ask for hints, approach, edge cases, or complexity...",
                    text: $viewModel.draftMessage,
                    axis: .vertical
                )
                .lineLimit(1...4)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .appInputField()

                Button {
                    Task {
                        await sendCurrentMessage()
                    }
                } label: {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 54, height: 54)
                        .background(
                            Circle()
                                .fill(AppTheme.heroGradient)
                        )
                }
                .buttonStyle(.plain)
                .disabled(viewModel.draftMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isSending)
                .opacity(viewModel.draftMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isSending ? 0.6 : 1)
            }
        }
        .padding(.top, 12)
    }

    private var typingIndicator: some View {
        HStack {
            HStack(spacing: 6) {
                Circle().fill(AppTheme.accent.opacity(0.35)).frame(width: 8, height: 8)
                Circle().fill(AppTheme.accent.opacity(0.55)).frame(width: 8, height: 8)
                Circle().fill(AppTheme.accent.opacity(0.75)).frame(width: 8, height: 8)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(AppTheme.accent.opacity(0.10))
            )

            Spacer()
        }
    }

    private func scrollToBottom(using proxy: ScrollViewProxy) {
        guard let lastMessageID = viewModel.messages.last?.id else { return }

        DispatchQueue.main.async {
            withAnimation(.easeOut(duration: 0.24)) {
                proxy.scrollTo(lastMessageID, anchor: .bottom)
            }
        }
    }

    private func sendCurrentMessage() async {
        let route = await viewModel.sendMessage(
            user: sessionStore.currentUser,
            tutorials: tutorialLibrary.tutorials,
            tutorialMatcher: { query in
                tutorialLibrary.bestMatch(for: query)
            }
        )

        guard let route else { return }

        switch route {
        case .handleAnalysis(let requestedHandle):
            appRouter.openHandleAnalysis(requestedHandle)
        case .tutorial(let tutorialID):
            appRouter.openTutorial(id: tutorialID)
        case .contestCalendar:
            appRouter.openContestCalendar()
        }

        dismiss()
    }
}

private struct MessageBubble: View {
    let message: CPChatMessage

    var body: some View {
        HStack {
            if message.role == .assistant {
                bubble
                Spacer(minLength: 40)
            } else {
                Spacer(minLength: 40)
                bubble
            }
        }
    }

    private var bubble: some View {
        Text(message.text)
            .font(.system(.subheadline, design: .rounded))
            .foregroundStyle(message.role == .assistant ? AppTheme.text : .white)
            .padding(.horizontal, 16)
            .padding(.vertical, 13)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(
                        message.role == .assistant
                            ? AnyShapeStyle(Color.white)
                            : AnyShapeStyle(AppTheme.heroGradient)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(message.role == .assistant ? AppTheme.cardBorder : Color.clear, lineWidth: 1)
            )
    }
}

#Preview {
    let session = SessionStore(previewUser: UserProfile(
        email: "demo@example.com",
        fullName: "Demo User",
        mobileNumber: "+8801000000000",
        primaryHandle: "tourist",
        friends: [
            FriendProfile(handle: "Benq")
        ]
    ))

    return NavigationStack {
        ChatbotWorkspaceView()
            .environmentObject(AppRouter())
            .environmentObject(TutorialLibraryStore())
            .environmentObject(session)
    }
}
