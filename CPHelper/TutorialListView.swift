import SwiftUI

struct TutorialListView: View {
    @EnvironmentObject private var tutorialLibrary: TutorialLibraryStore

    @State private var searchText = ""
    @State private var selectedCategory = "All"

    private var categories: [String] {
        ["All"] + tutorialLibrary.tutorials.map(\.category).uniqued().sorted()
    }

    private var filteredTutorials: [AlgorithmTutorial] {
        tutorialLibrary.tutorials.filter { tutorial in
            let matchesCategory = selectedCategory == "All" || tutorial.category == selectedCategory

            guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                return matchesCategory
            }

            let query = normalize(searchText)
            let haystack = normalize("\(tutorial.title) \(tutorial.category) \(tutorial.explanation)")
            return matchesCategory && haystack.contains(query)
        }
    }

    var body: some View {
        ZStack {
            AppBackdrop()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    heroSection
                    searchSection

                    if tutorialLibrary.isLoading && tutorialLibrary.tutorials.isEmpty {
                        InlineMessageCard(
                            icon: "book.pages.fill",
                            title: "Loading cp-algorithms",
                            detail: "Fetching the latest tutorial catalog and preparing a cleaner in-app reading experience."
                        )
                    } else if filteredTutorials.isEmpty {
                        InlineMessageCard(
                            icon: "magnifyingglass",
                            title: "No tutorials matched",
                            detail: "Try a broader search term or switch back to all categories."
                        )
                    } else {
                        tutorialGrid
                    }
                }
                .padding(20)
            }
        }
        .navigationTitle("Tutorials")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await tutorialLibrary.loadIfNeeded()
        }
        .refreshable {
            await tutorialLibrary.refresh(force: true)
        }
    }

    private var heroSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("cp-algorithms, redesigned for practice.")
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(AppTheme.text)

            Text("Browse the live tutorial catalog, search by topic, and open a cleaner detail view before jumping into the full article.")
                .font(.system(.body, design: .rounded))
                .foregroundStyle(AppTheme.mutedText)

            HStack(spacing: 10) {
                MetricChip(title: "Articles", value: "\(tutorialLibrary.tutorials.count)")
                MetricChip(title: "Source", value: "cp-algorithms")
                MetricChip(title: "Categories", value: "\(max(categories.count - 1, 0))")
            }

            if let errorMessage = tutorialLibrary.errorMessage {
                Text(errorMessage)
                    .font(.system(.footnote, design: .rounded))
                    .foregroundStyle(Color(red: 0.80, green: 0.24, blue: 0.24))
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color.red.opacity(0.08))
                    )
            }
        }
    }

    private var searchSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionTitle(
                title: "Find a topic",
                subtitle: "Search by data structure, technique, category, or article title."
            )

            TextField("Search tutorials like DSU, DP, BFS, suffix array...", text: $searchText)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .appInputField()

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(categories, id: \.self) { category in
                        Button {
                            selectedCategory = category
                        } label: {
                            Text(category)
                                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                                .foregroundStyle(selectedCategory == category ? .white : AppTheme.text)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .background(
                                    Capsule()
                                        .fill(
                                            selectedCategory == category
                                                ? AnyShapeStyle(AppTheme.heroGradient)
                                                : AnyShapeStyle(Color.white.opacity(0.9))
                                        )
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .appCard()
    }

    private var tutorialGrid: some View {
        LazyVStack(spacing: 14) {
            ForEach(filteredTutorials) { tutorial in
                NavigationLink(destination: TutorialDetailView(tutorial: tutorial)) {
                    TutorialCard(tutorial: tutorial)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func normalize(_ text: String) -> String {
        text
            .lowercased()
            .replacingOccurrences(of: #"[^a-z0-9\s]"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private struct TutorialCard: View {
    let tutorial: AlgorithmTutorial

    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    InfoBadge(title: tutorial.category, tint: AppTheme.accentSecondary)
                    InfoBadge(title: tutorial.difficulty, tint: AppTheme.warm)
                }

                Text(tutorial.title)
                    .font(.system(.headline, design: .rounded).weight(.bold))
                    .foregroundStyle(AppTheme.text)
                    .multilineTextAlignment(.leading)

                Text(tutorial.explanation)
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(AppTheme.mutedText)
                    .multilineTextAlignment(.leading)

                Text(tutorial.practiceTip)
                    .font(.system(.footnote, design: .rounded))
                    .foregroundStyle(AppTheme.accent)
            }

            Spacer()

            Image(systemName: "arrow.right.circle.fill")
                .font(.system(size: 28))
                .foregroundStyle(AppTheme.accent)
        }
        .appCard()
    }
}

private extension Array where Element == String {
    func uniqued() -> [String] {
        var seen: Set<String> = []
        return self.filter { value in
            guard !seen.contains(value) else { return false }
            seen.insert(value)
            return true
        }
    }
}

#Preview {
    NavigationStack {
        TutorialListView()
            .environmentObject(TutorialLibraryStore())
    }
}
