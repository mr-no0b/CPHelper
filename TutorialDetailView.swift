

import SwiftUI

struct TutorialDetailView: View {
    let tutorial: AlgorithmTutorial

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(tutorial.title)
                        .font(.largeTitle)
                        .fontWeight(.bold)

                    Label("Difficulty: \(tutorial.difficulty)", systemImage: "graduationcap.fill")
                        .foregroundStyle(.secondary)
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
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(tutorial.title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func tutorialCard(title: String, iconName: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: iconName)
                .font(.headline)

            Text(text)
                .font(.body)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.secondarySystemBackground))
        )
    }
}

#Preview {
    NavigationStack {
        TutorialDetailView(tutorial: .sample)
    }
}
