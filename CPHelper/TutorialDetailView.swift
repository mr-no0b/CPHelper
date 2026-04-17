

import SwiftUI

struct TutorialDetailView: View {
    let tutorial: AlgorithmTutorial

    var body: some View {
        ZStack {
            AppBackdrop()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(tutorial.title)
                            .font(.system(size: 34, weight: .bold, design: .rounded))
                            .foregroundStyle(AppTheme.text)

                        Label("Difficulty: \(tutorial.difficulty)", systemImage: "graduationcap.fill")
                            .foregroundStyle(AppTheme.mutedText)
                    }

                    tutorialCard(
                        title: "Short Explanation",
                        iconName: "lightbulb.fill",
                        text: tutorial.explanation
                    )

                    tutorialCard(
                        title: "Practice Tip",
                        iconName: "target",
                        text: tutorial.practiceTip
                    )
                }
                .padding(20)
            }
        }
        .navigationTitle(tutorial.title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func tutorialCard(title: String, iconName: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: iconName)
                .font(.headline)

            Text(text)
                .font(.body)
                .foregroundStyle(AppTheme.mutedText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .appCard()
    }
}

#Preview {
    NavigationStack {
        TutorialDetailView(tutorial: .sample)
    }
}
