import SwiftUI

struct ToolkitView: View {
    @EnvironmentObject private var sessionStore: SessionStore

    var body: some View {
        ZStack {
            AppBackdrop()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Practice toolkit")
                            .font(.system(size: 34, weight: .bold, design: .rounded))
                            .foregroundStyle(AppTheme.text)

                        Text("Suggested problems, weak-area targeting, rating roadmap guidance, and a todo list built around real Codeforces handles.")
                            .font(.system(.body, design: .rounded))
                            .foregroundStyle(AppTheme.mutedText)
                    }

                    VStack(spacing: 16) {
                        NavigationLink(destination: SuggestedProblemsView()) {
                            ToolkitCard(
                                title: "Suggested Problems",
                                subtitle: "Live Codeforces recommendations based on rating band and solved history.",
                                icon: "wand.and.stars.inverse",
                                tint: AppTheme.accent
                            )
                        }

                        NavigationLink(destination: WeakAreasView()) {
                            ToolkitCard(
                                title: "Weak Areas",
                                subtitle: "See low-conversion topics and targeted follow-up practice with pie charts.",
                                icon: "chart.pie.fill",
                                tint: AppTheme.warning
                            )
                        }

                        NavigationLink(destination: PracticeListView()) {
                            ToolkitCard(
                                title: "Todo List",
                                subtitle: "\(sessionStore.currentUser?.todoProblems.count ?? 0) saved Codeforces problems across your tracked handles.",
                                icon: "checklist.checked",
                                tint: AppTheme.success
                            )
                        }

                        NavigationLink(destination: RoadmapView()) {
                            ToolkitCard(
                                title: "Roadmap",
                                subtitle: "Static training stages for climbing from one rating band to the next.",
                                icon: "map.fill",
                                tint: AppTheme.warm
                            )
                        }

                        NavigationLink(destination: TutorialListView()) {
                            ToolkitCard(
                                title: "Algorithm Tutorials",
                                subtitle: "Quick refreshers for core techniques and patterns.",
                                icon: "book.pages.fill",
                                tint: AppTheme.accent
                            )
                        }
                    }
                }
                .padding(20)
            }
        }
        .navigationTitle("Toolkit")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct ToolkitCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let tint: Color

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 58, height: 58)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(tint.opacity(0.12))
                )

            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.system(.headline, design: .rounded).weight(.bold))
                    .foregroundStyle(AppTheme.text)

                Text(subtitle)
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(AppTheme.mutedText)
                    .multilineTextAlignment(.leading)
            }

            Spacer()

            Image(systemName: "arrow.right")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(AppTheme.mutedText)
        }
        .appCard()
    }
}
