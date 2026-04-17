import SwiftUI

struct ChatbotWorkspaceView: View {
    let problem: CodeforcesProblem
    let handle: String

    @State private var draftMessage = ""

    var body: some View {
        ZStack {
            AppBackdrop()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    headerCard
                    contextCard
                    composerCard
                }
                .padding(20)
            }
        }
        .navigationTitle("Chatbot")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Problem context is ready.")
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundStyle(AppTheme.text)

            Text("This screen is ready for your future chatbot integration. The selected handle and Codeforces problem are already attached as context.")
                .font(.system(.body, design: .rounded))
                .foregroundStyle(AppTheme.mutedText)
        }
        .appCard()
    }

    private var contextCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionTitle(
                title: "Attached context",
                subtitle: "Anything you ask here can later be grounded in this problem."
            )

            HStack(spacing: 10) {
                InfoBadge(title: "@\(handle)", tint: AppTheme.accent)

                if let rating = problem.rating {
                    InfoBadge(title: "Rating \(rating)", tint: AppTheme.accentSecondary)
                }
            }

            Text(problem.name)
                .font(.system(.headline, design: .rounded).weight(.bold))
                .foregroundStyle(AppTheme.text)

            Text(problem.displayID)
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(AppTheme.mutedText)

            if !problem.tags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(problem.tags, id: \.self) { tag in
                            Text(tag)
                                .font(.system(.caption, design: .rounded).weight(.medium))
                                .foregroundStyle(AppTheme.accentSecondary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(
                                    Capsule()
                                        .fill(AppTheme.accentSecondary.opacity(0.12))
                                )
                        }
                    }
                }
            }
        }
        .appCard()
    }

    private var composerCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionTitle(
                title: "Prompt draft",
                subtitle: "A placeholder composer so your future chatbot can drop in without redesign work."
            )

            TextEditor(text: $draftMessage)
                .scrollContentBackground(.hidden)
                .font(.system(.body, design: .rounded))
                .frame(minHeight: 160)
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.white.opacity(0.92))
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(AppTheme.cardBorder, lineWidth: 1)
                        )
                )

            Text("Suggested first prompts: explain the solution idea, find corner cases, or compare two approaches.")
                .font(.system(.footnote, design: .rounded))
                .foregroundStyle(AppTheme.mutedText)

            PracticeActionButton(
                title: "Send (coming soon)",
                systemImage: "paperplane.fill",
                tint: AppTheme.accent,
                disabled: true,
                action: {}
            )
        }
        .appCard()
    }
}

#Preview {
    NavigationStack {
        ChatbotWorkspaceView(
            problem: CodeforcesProblem(
                contestId: 231,
                index: "A",
                name: "Team",
                rating: 800,
                tags: ["brute force", "greedy"],
                solvedCount: 100000
            ),
            handle: "tourist"
        )
    }
}
