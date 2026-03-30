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
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                filterCard

                if let problem = recommendedProblem {
                    recommendationCard(problem: problem)
                }

                Text("Problems")
                    .font(.title3)
                    .fontWeight(.semibold)

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
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Problem Picker")
    }

    private var filterCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Find by Topic", systemImage: "line.3.horizontal.decrease.circle")
                .font(.headline)

            TextField("Example: dp, graphs, binary search", text: $topicSearch)
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color(.systemBackground))
                )

            Toggle("Show only unsolved problems", isOn: $showOnlyUnsolved)

            Button {
                recommendedProblem = filteredProblems
                    .filter { !$0.isSolved }
                    .sorted { $0.rating < $1.rating }
                    .first
            } label: {
                Text("Pick Recommended Problem")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.orange, in: RoundedRectangle(cornerRadius: 14))
                    .foregroundStyle(.white)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.secondarySystemBackground))
        )
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
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        appData.isSaved(problem) ? Color.green.opacity(0.2) : Color.blue,
                        in: RoundedRectangle(cornerRadius: 12)
                    )
                    .foregroundStyle(appData.isSaved(problem) ? Color.green : Color.white)
            }
            .disabled(appData.isSaved(problem))
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.yellow.opacity(0.14))
        )
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
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        appData.isSaved(problem) ? Color.gray.opacity(0.15) : Color.blue,
                        in: RoundedRectangle(cornerRadius: 12)
                    )
                    .foregroundStyle(appData.isSaved(problem) ? Color.secondary : Color.white)
            }
            .disabled(appData.isSaved(problem))
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color(.secondarySystemBackground))
        )
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
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color(.secondarySystemBackground))
        )
    }
}

#Preview {
    NavigationStack {
        ProblemPickerView()
            .environmentObject(AppData())
    }
}
