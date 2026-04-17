import SwiftUI

struct ToolkitView: View {
    var body: some View {
        ZStack {
            AppBackdrop()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Practice toolkit")
                            .font(.system(size: 34, weight: .bold, design: .rounded))
                            .foregroundStyle(AppTheme.text)

                        Text("Keep the classic helper tools nearby while the new auth and analysis system handles profiles and live insight.")
                            .font(.system(.body, design: .rounded))
                            .foregroundStyle(AppTheme.mutedText)
                    }

                    VStack(spacing: 16) {
                        NavigationLink(destination: ProblemPickerView()) {
                            ToolkitCard(
                                title: "Problem Picker",
                                subtitle: "Filter local problems and build your next practice queue.",
                                icon: "scope",
                                tint: AppTheme.warm
                            )
                        }

                        NavigationLink(destination: PracticeListView()) {
                            ToolkitCard(
                                title: "Practice List",
                                subtitle: "Review saved problems and mark practice progress.",
                                icon: "checklist.checked",
                                tint: AppTheme.success
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
