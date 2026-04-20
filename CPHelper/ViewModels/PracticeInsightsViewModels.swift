import Foundation

struct RatingRecommendationSlice: Identifiable, Equatable {
    let title: String
    let count: Int

    var id: String { title }
}

struct WeakTopic: Identifiable, Equatable {
    let topic: TopicPerformance
    let weaknessScore: Double

    var id: String {
        topic.id
    }

    var note: String {
        "\(NumberFormatting.percentage(topic.acceptanceRate)) AC • \(topic.attemptedCount) tries"
    }
}

struct WeakTopicRecommendation: Identifiable, Equatable {
    let weakTopic: WeakTopic
    let problems: [CodeforcesProblem]

    var id: String {
        weakTopic.id
    }
}

@MainActor
final class SuggestedProblemsViewModel: ObservableObject {
    @Published private(set) var analysis: HandleAnalysis?
    @Published private(set) var ratingSuggestions: [CodeforcesProblem] = []
    @Published private(set) var ratingMix: [RatingRecommendationSlice] = []
    @Published private(set) var weakTopics: [WeakTopic] = []
    @Published private(set) var weakRecommendations: [WeakTopicRecommendation] = []
    @Published private(set) var ratingBandLabel: String = "800-1000"
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    private let analysisService: CodeforcesAnalysisService
    private let catalogService: CodeforcesProblemCatalogService

    init(
        analysisService: CodeforcesAnalysisService = .shared,
        catalogService: CodeforcesProblemCatalogService = .shared
    ) {
        self.analysisService = analysisService
        self.catalogService = catalogService
    }

    func load(for handle: String) async {
        let trimmedHandle = handle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedHandle.isEmpty else {
            errorMessage = "Add a primary handle first."
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            let analysis = try await analysisService.loadAnalysis(for: trimmedHandle)
            let catalog = try await catalogService.loadProblemset()
            let ratingWindow = Self.makeRatingWindow(for: analysis)
            let weakTopics = Self.buildWeakTopics(from: analysis)
            let ratingSuggestions = Self.buildRatingSuggestions(
                for: analysis,
                using: catalog,
                window: ratingWindow
            )

            self.analysis = analysis
            self.weakTopics = weakTopics
            self.ratingSuggestions = ratingSuggestions
            self.ratingMix = Self.buildRatingMix(from: ratingSuggestions, peakRating: analysis.summary.maxRating ?? analysis.effectiveCurrentRating)
            self.weakRecommendations = Self.buildWeakRecommendations(
                weakTopics: weakTopics,
                analysis: analysis,
                catalog: catalog
            )
            self.ratingBandLabel = "\(ratingWindow.lowerBound)-\(ratingWindow.upperBound)"
        } catch {
            errorMessage = error.localizedDescription
            analysis = nil
            ratingSuggestions = []
            ratingMix = []
            weakTopics = []
            weakRecommendations = []
        }

        isLoading = false
    }

    static func makeRatingWindow(for analysis: HandleAnalysis) -> ClosedRange<Int> {
        let peakRating = max(800, analysis.summary.maxRating ?? analysis.effectiveCurrentRating)
        let lower = max(800, roundedDown(peakRating - 300))
        let upper = min(3500, roundedUp(peakRating + 100))
        return lower...max(lower + 200, upper)
    }

    static func buildRatingSuggestions(
        for analysis: HandleAnalysis,
        using catalog: [CodeforcesProblem],
        window: ClosedRange<Int>
    ) -> [CodeforcesProblem] {
        let solvedProblemIDs = analysis.solvedProblemIDs
        let peakRating = max(800, analysis.summary.maxRating ?? analysis.effectiveCurrentRating)
        let targetRating = min(window.upperBound, max(window.lowerBound, peakRating - 50))

        var candidates = filterCandidates(
            from: catalog,
            solvedProblemIDs: solvedProblemIDs,
            ratingWindow: window,
            preferredTags: nil
        )

        if candidates.count < 8 {
            let widenedLower = max(800, window.lowerBound - 200)
            let widenedUpper = min(3500, window.upperBound + 200)
            candidates = filterCandidates(
                from: catalog,
                solvedProblemIDs: solvedProblemIDs,
                ratingWindow: widenedLower...widenedUpper,
                preferredTags: nil
            )
        }

        return rankCandidates(candidates, targetRating: targetRating)
            .prefix(10)
            .map(\.problem)
    }

    static func buildRatingMix(
        from suggestions: [CodeforcesProblem],
        peakRating: Int
    ) -> [RatingRecommendationSlice] {
        let comfort = suggestions.filter { ($0.rating ?? peakRating) < peakRating - 100 }.count
        let core = suggestions.filter {
            let rating = $0.rating ?? peakRating
            return (peakRating - 100...peakRating + 50).contains(rating)
        }.count
        let stretch = max(suggestions.count - comfort - core, 0)

        return [
            RatingRecommendationSlice(title: "Comfort", count: comfort),
            RatingRecommendationSlice(title: "Core", count: core),
            RatingRecommendationSlice(title: "Stretch", count: stretch)
        ]
        .filter { $0.count > 0 }
    }

    static func buildWeakTopics(from analysis: HandleAnalysis) -> [WeakTopic] {
        analysis.topicPerformance
            .filter { $0.attemptedCount >= 3 }
            .map { topic in
                let attemptWeight = Double(topic.attemptedCount)
                let weaknessScore = (1 - topic.acceptanceRate) * attemptWeight
                return WeakTopic(topic: topic, weaknessScore: weaknessScore)
            }
            .sorted { lhs, rhs in
                if lhs.weaknessScore == rhs.weaknessScore {
                    return lhs.topic.attemptedCount > rhs.topic.attemptedCount
                }
                return lhs.weaknessScore > rhs.weaknessScore
            }
            .prefix(4)
            .map { $0 }
    }

    static func buildWeakRecommendations(
        weakTopics: [WeakTopic],
        analysis: HandleAnalysis,
        catalog: [CodeforcesProblem]
    ) -> [WeakTopicRecommendation] {
        let solvedProblemIDs = analysis.solvedProblemIDs
        let targetRating = analysis.summary.maxRating ?? analysis.effectiveCurrentRating
        let window = max(800, targetRating - 250)...min(3500, targetRating + 50)

        return weakTopics.prefix(3).compactMap { weakTopic in
            let preferredTags = Set([weakTopic.topic.tag.lowercased()])
            let candidates = filterCandidates(
                from: catalog,
                solvedProblemIDs: solvedProblemIDs,
                ratingWindow: window,
                preferredTags: preferredTags
            )

            let rankedProblems = rankCandidates(candidates, targetRating: targetRating)
                .prefix(2)
                .map(\.problem)

            guard !rankedProblems.isEmpty else { return nil }

            return WeakTopicRecommendation(
                weakTopic: weakTopic,
                problems: rankedProblems
            )
        }
    }

    static func filterCandidates(
        from catalog: [CodeforcesProblem],
        solvedProblemIDs: Set<String>,
        ratingWindow: ClosedRange<Int>,
        preferredTags: Set<String>?
    ) -> [CodeforcesProblem] {
        catalog.filter { problem in
            guard let rating = problem.rating else { return false }
            guard !solvedProblemIDs.contains(problem.id) else { return false }
            guard ratingWindow.contains(rating) else { return false }
            guard !problem.tags.contains(where: { ["*special", "interactive"].contains($0.lowercased()) }) else {
                return false
            }

            if let preferredTags {
                return !preferredTags.isDisjoint(with: Set(problem.tags.map { $0.lowercased() }))
            }

            return true
        }
    }

    static func rankCandidates(
        _ candidates: [CodeforcesProblem],
        targetRating: Int
    ) -> [(problem: CodeforcesProblem, score: Int)] {
        candidates.map { problem in
            let ratingDistance = abs((problem.rating ?? targetRating) - targetRating)
            let popularityBoost = min(problem.solvedCount ?? 0, 20_000) / 500
            let score = ratingDistance - popularityBoost
            return (problem, score)
        }
        .sorted { lhs, rhs in
            if lhs.score == rhs.score {
                return (lhs.problem.solvedCount ?? 0) > (rhs.problem.solvedCount ?? 0)
            }
            return lhs.score < rhs.score
        }
    }

    private static func roundedDown(_ value: Int) -> Int {
        max(800, (value / 100) * 100)
    }

    private static func roundedUp(_ value: Int) -> Int {
        ((value + 99) / 100) * 100
    }
}
