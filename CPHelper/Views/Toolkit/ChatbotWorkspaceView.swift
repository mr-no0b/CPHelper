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

    private var quickPrompts: [String] {
        if let problem {
            return [
                "Break down \(problem.displayID)",
                "What edge cases should I test?",
                "Give me a calm next step."
            ]
        }

        return [
            "Analyze my primary handle",
            "Explain DSU simply",
            "Give me a 2-week roadmap",
            "What should I do after a bad session?"
        ]
    }

    var body: some View {
        ZStack {
            AppBackdrop()

            VStack(spacing: 14) {
                headerCard

                if let problem {
                    problemContextCard(problem)
                }

                profilePulseCard
                messagePanel
                composerPanel
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 12)
        }
        .navigationTitle("CP Coach")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await tutorialLibrary.loadIfNeeded()
            await viewModel.prepare(user: sessionStore.currentUser)
        }
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("CP Coach")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(AppTheme.text)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(quickPrompts, id: \.self) { prompt in
                        Button {
                            viewModel.draftMessage = prompt
                        } label: {
                            Text(prompt)
                                .font(.system(.caption, design: .rounded).weight(.semibold))
                                .foregroundStyle(AppTheme.accent)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .background(
                                    Capsule()
                                        .fill(AppTheme.accent.opacity(0.12))
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .appCard()
    }

    private func problemContextCard(_ problem: CodeforcesProblem) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                if let handle {
                    InfoBadge(title: "@\(handle)", tint: AppTheme.accent)
                }

                if let rating = problem.rating {
                    InfoBadge(title: "Rating \(rating)", tint: AppTheme.warm)
                }
            }

            Text(problem.name)
                .font(.system(.headline, design: .rounded).weight(.bold))
                .foregroundStyle(AppTheme.text)

            Text(problem.displayID)
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(AppTheme.mutedText)
        }
        .appCard()
    }

    private var profilePulseCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(title: "Profile Pulse", subtitle: "Loaded handle context")

            if viewModel.isPreparingContext && viewModel.handleInsights.isEmpty {
                HStack(spacing: 12) {
                    ProgressView()
                        .tint(AppTheme.accent)

                    Text("Loading handle context...")
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(AppTheme.mutedText)
                }
            } else if viewModel.handleInsights.isEmpty {
                Text("No handle context loaded yet.")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(AppTheme.mutedText)
            } else {
                VStack(spacing: 10) {
                    ForEach(viewModel.handleInsights, id: \.handle) { insight in
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 5) {
                                HStack(spacing: 8) {
                                    Text("@\(insight.handle)")
                                        .font(.system(.subheadline, design: .rounded).weight(.bold))
                                        .foregroundStyle(AppTheme.text)

                                    if insight.isPrimary {
                                        InfoBadge(title: "Primary", tint: AppTheme.accent)
                                    }
                                }

                                Text("\(insight.roadmapStage.title) • \(insight.solvedCount) solved")
                                    .font(.system(.caption, design: .rounded))
                                    .foregroundStyle(AppTheme.mutedText)
                            }

                            Spacer()

                            if let currentRating = insight.currentRating {
                                InfoBadge(title: "\(currentRating)", tint: AppTheme.warm)
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(Color.white.opacity(0.88))
                        )
                    }
                }
            }
        }
        .appCard()
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
                .padding(.vertical, 4)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .fill(Color.white.opacity(0.88))
                    .overlay(
                        RoundedRectangle(cornerRadius: 30, style: .continuous)
                            .stroke(AppTheme.cardBorder, lineWidth: 1)
                    )
            )
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
                    "Ask about handles, DSA, roadmaps, tutorials, or strategy...",
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
        .appCard()
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
