import SwiftUI

struct ProblemPickerView: View {
    @EnvironmentObject private var appData: AppData

    @State private var topicSearch: String = ""
    @State private var showOnlyUnsolved: Bool = false
    @State private var recommendedProblem: PracticeProblem?

    private var filteredProblems: [PracticeProblem] {
        appData.problems.filter { problem in
            let trimmedSearch = topicSearch.trimmingCharacters(in: .whitespacesAndNewlines)
            let matchesTopic = trimmedSearch.isEmpty || problem.topic.localizedCaseInsensitiveContains(trimmedSearch)
            let matchesSolvedFilter = !showOnlyUnsolved || !problem.isSolved
            return matchesTopic && matchesSolvedFilter
        }
    }

    var body: some View {
        ZStack {
            AppBackdrop()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    filterCard

                    if let problem = recommendedProblem {
                        recommendationCard(problem: problem)
                    }

                    Text("Problems")
                        .font(.appSection)
                        .foregroundStyle(AppTheme.text)

                    VStack(spacing: 14) {
                        if filteredProblems.isEmpty {
                            emptyStateCard
                        } else {
                            ForEach(filteredProblems) { problem in
                                problemCard(problem: problem)
                            }
                        }
                    }
                }
                .padding(20)
            }
        }
        .navigationTitle("Problem Picker")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var filterCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Find by Topic", systemImage: "line.3.horizontal.decrease.circle")
                .font(.headline)

            TextField("Example: dp, graphs, binary search", text: $topicSearch)
                .appInputField()

            Toggle("Show only unsolved problems", isOn: $showOnlyUnsolved)
                .tint(AppTheme.accent)

            Button {
                recommendedProblem = filteredProblems
                    .filter { !$0.isSolved }
                    .sorted { $0.rating < $1.rating }
                    .first
            } label: {
                Text("Pick Recommended Problem")
            }
            .buttonStyle(AppPrimaryButtonStyle())
        }
        .appCard()
    }

    private func recommendationCard(problem: PracticeProblem) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Recommended Problem", systemImage: "star.fill")
                .font(.headline)
                .foregroundStyle(.orange)

            Text(problem.name)
                .font(.title3)
                .fontWeight(.bold)

            HStack {
                Label("Rating \(problem.rating)", systemImage: "chart.bar.fill")
                Spacer()
                Label(problem.topic, systemImage: "tag.fill")
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)

            Button {
                appData.saveProblem(problem)
            } label: {
                Text(appData.isSaved(problem) ? "Saved to Practice List" : "Save to Practice List")
            }
            .buttonStyle(AppSecondaryButtonStyle())
            .disabled(appData.isSaved(problem))
        }
        .appCard()
    }

    private func problemCard(problem: PracticeProblem) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(problem.name)
                        .font(.headline)

                    Text(problem.id)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(problem.isSolved ? "Solved" : "Unsolved")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        problem.isSolved ? Color.green.opacity(0.15) : Color.orange.opacity(0.15),
                        in: Capsule()
                    )
                    .foregroundStyle(problem.isSolved ? Color.green : Color.orange)
            }

            HStack {
                Label("Rating \(problem.rating)", systemImage: "chart.bar")
                Spacer()
                Label(problem.topic, systemImage: "tag.fill")
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)

            Button {
                appData.saveProblem(problem)
            } label: {
                Text(appData.isSaved(problem) ? "Already Saved" : "Save for Practice")
            }
            .buttonStyle(AppSecondaryButtonStyle())
            .disabled(appData.isSaved(problem))
        }
        .appCard()
    }

    private var emptyStateCard: some View {
        VStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 28))
                .foregroundStyle(.secondary)

            Text("No matching problems found.")
                .font(.headline)

            Text("Try a different topic keyword or turn off the unsolved filter.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .appCard()
    }
}

#Preview {
    NavigationStack {
        ProblemPickerView()
            .environmentObject(AppData())
    }
}
