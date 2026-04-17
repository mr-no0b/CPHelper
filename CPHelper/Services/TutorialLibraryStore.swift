import Combine
import Foundation

@MainActor
final class TutorialLibraryStore: ObservableObject {
    @Published private(set) var tutorials: [AlgorithmTutorial]
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?
    @Published private(set) var lastRefresh: Date?

    private let service: TutorialCatalogService

    init(service: TutorialCatalogService = .shared) {
        self.service = service
        self.tutorials = (try? TutorialLibraryStore.loadFallbackTutorials()) ?? [.sample]
    }

    func loadIfNeeded() async {
        guard lastRefresh == nil else { return }
        await refresh(force: false)
    }

    func refresh(force: Bool = true) async {
        guard !isLoading else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            let fetchedTutorials = try await service.loadTutorials(forceRefresh: force)
            tutorials = fetchedTutorials
            errorMessage = nil
            lastRefresh = .now
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func tutorial(withID id: String) -> AlgorithmTutorial? {
        tutorials.first(where: { $0.id == id })
    }

    func bestMatch(for query: String) -> AlgorithmTutorial? {
        let normalizedQuery = normalize(query)
        guard !normalizedQuery.isEmpty else { return nil }

        let queryTokens = Set(normalizedQuery.split(separator: " ").map(String.init))
        var bestTutorial: AlgorithmTutorial?
        var bestScore = 0

        for tutorial in tutorials {
            let tutorialTitle = normalize(tutorial.title)
            let tutorialCategory = normalize(tutorial.category)
            let combinedText = "\(tutorialTitle) \(tutorialCategory)"
            let tutorialTokens = Set(combinedText.split(separator: " ").map(String.init))

            var score = 0

            if tutorialTitle.contains(normalizedQuery) {
                score += 120
            }

            if tutorialCategory.contains(normalizedQuery) {
                score += 40
            }

            score += queryTokens.intersection(tutorialTokens).count * 18

            if tutorialTitle.replacingOccurrences(of: " ", with: "")
                .contains(normalizedQuery.replacingOccurrences(of: " ", with: "")) {
                score += 25
            }

            if score > bestScore {
                bestScore = score
                bestTutorial = tutorial
            }
        }

        return bestScore >= 28 ? bestTutorial : nil
    }

    private static func loadFallbackTutorials() throws -> [AlgorithmTutorial] {
        let directURL = Bundle.main.url(forResource: "tutorials.json", withExtension: nil)
        let resourcesURL = Bundle.main.url(forResource: "tutorials.json", withExtension: nil, subdirectory: "Resources")

        guard let url = directURL ?? resourcesURL else {
            throw CodeforcesError.emptyResponse
        }

        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode([AlgorithmTutorial].self, from: data)
    }

    private func normalize(_ text: String) -> String {
        text
            .lowercased()
            .replacingOccurrences(of: #"[^a-z0-9\s]"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
