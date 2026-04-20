import SwiftUI

struct ToolkitView: View {
    @EnvironmentObject private var sessionStore: SessionStore

    var body: some View {
        ZStack {
            AppBackdrop()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    Text("Toolkit")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundStyle(AppTheme.text)

                    VStack(spacing: 14) {
                        NavigationLink(destination: AnalyzeHandleView()) {
                            ToolkitCard(
                                title: "Analyze",
                                subtitle: "Analyze any public handle.",
                                icon: "chart.xyaxis.line",
                                tint: AppTheme.accent
                            )
                        }

                        NavigationLink(destination: FriendsView()) {
                            ToolkitCard(
                                title: "Friends",
                                subtitle: "\(sessionStore.currentUser?.friends.count ?? 0) saved friend profiles.",
                                icon: "person.2.fill",
                                tint: AppTheme.accentSecondary
                            )
                        }

                        NavigationLink(destination: ContestCalendarView()) {
                            ToolkitCard(
                                title: "Contest Calendar",
                                subtitle: "Upcoming contests and registration tracking.",
                                icon: "calendar.badge.clock",
                                tint: AppTheme.warm
                            )
                        }

                        NavigationLink(destination: SuggestedProblemsView()) {
                            ToolkitCard(
                                title: "Suggested Problems",
                                subtitle: "Rating suggestions, weak tags, and targeted fixes.",
                                icon: "sparkles.rectangle.stack.fill",
                                tint: AppTheme.accent
                            )
                        }

                        NavigationLink(destination: PracticeListView()) {
                            ToolkitCard(
                                title: "ToDo",
                                subtitle: "\(sessionStore.currentUser?.todoProblems.count ?? 0) saved problems.",
                                icon: "checklist.checked",
                                tint: AppTheme.success
                            )
                        }

                        NavigationLink(destination: RoadmapView()) {
                            ToolkitCard(
                                title: "Roadmap",
                                subtitle: "Static target-rating roadmap.",
                                icon: "map.fill",
                                tint: AppTheme.warning
                            )
                        }

                        NavigationLink(destination: TutorialListView()) {
                            ToolkitCard(
                                title: "Tutorials",
                                subtitle: "cp-algorithms with in-app summaries.",
                                icon: "book.pages.fill",
                                tint: AppTheme.accentSecondary
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
                .frame(width: 56, height: 56)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(tint.opacity(0.12))
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(.headline, design: .rounded).weight(.bold))
                    .foregroundStyle(AppTheme.text)

                Text(subtitle)
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(AppTheme.mutedText)
            }

            Spacer()

            Image(systemName: "arrow.right")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(AppTheme.mutedText)
        }
        .appCard()
    }
}
