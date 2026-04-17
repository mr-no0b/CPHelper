import Foundation

struct WeakTopic: Identifiable, Equatable {
    let topic: TopicPerformance
    let weaknessScore: Double

    var id: String {
        topic.id
    }

    var note: String {
        "\(NumberFormatting.percentage(topic.acceptanceRate)) acceptance over \(topic.attemptedCount) attempts"
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
    @Published private(set) var suggestions: [CodeforcesProblem] = []
    @Published private(set) var ratingBandLabel: String = "800-1000"
    @Published private(set) var recommendationSummary: String = ""
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
            errorMessage = "Add a Codeforces handle first."
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            let analysis = try await analysisService.loadAnalysis(for: trimmedHandle)
            let catalog = try await catalogService.loadProblemset()
            let window = Self.makeRatingWindow(for: analysis)

            self.analysis = analysis
            suggestions = Self.buildSuggestions(
                for: analysis,
                using: catalog,
                window: window
            )
            ratingBandLabel = "\(window.lowerBound)-\(window.upperBound)"
            recommendationSummary = Self.makeSummary(for: analysis, window: window)
        } catch {
            errorMessage = error.localizedDescription
            suggestions = []
        }

        isLoading = false
    }

    static func buildSuggestions(
        for analysis: HandleAnalysis,
        using catalog: [CodeforcesProblem],
        window: ClosedRange<Int>
    ) -> [CodeforcesProblem] {
        let solvedProblemIDs = analysis.solvedProblemIDs
        let targetRating = min(window.upperBound, max(window.lowerBound, analysis.effectiveCurrentRating + 100))

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

    static func makeRatingWindow(for analysis: HandleAnalysis) -> ClosedRange<Int> {
        let currentRating = max(800, analysis.summary.currentRating ?? analysis.summary.maxRating ?? 800)
        let peakRating = max(currentRating, analysis.summary.maxRating ?? currentRating)

        let lower = max(800, roundedDown(min(currentRating, peakRating) - 100))
        let upperBase = max(peakRating, currentRating + 200)
        let upper = min(3500, roundedUp(upperBase))

        return lower...max(lower + 200, upper)
    }

    static func makeSummary(for analysis: HandleAnalysis, window: ClosedRange<Int>) -> String {
        let currentRating = analysis.summary.currentRating.map(String.init) ?? "unrated"
        let peakRating = analysis.summary.maxRating.map(String.init) ?? currentRating
        return "Built around current rating \(currentRating) and peak \(peakRating), with most picks centered in \(window.lowerBound)-\(window.upperBound)."
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

@MainActor
final class WeakAreasViewModel: ObservableObject {
    @Published private(set) var analysis: HandleAnalysis?
    @Published private(set) var weakTopics: [WeakTopic] = []
    @Published private(set) var recommendations: [WeakTopicRecommendation] = []
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
            errorMessage = "Add a Codeforces handle first."
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            let analysis = try await analysisService.loadAnalysis(for: trimmedHandle)
            let catalog = try await catalogService.loadProblemset()
            let weakTopics = Self.buildWeakTopics(from: analysis)

            self.analysis = analysis
            self.weakTopics = weakTopics
            recommendations = Self.buildRecommendations(
                weakTopics: weakTopics,
                analysis: analysis,
                catalog: catalog
            )
        } catch {
            errorMessage = error.localizedDescription
            weakTopics = []
            recommendations = []
        }

        isLoading = false
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

    static func buildRecommendations(
        weakTopics: [WeakTopic],
        analysis: HandleAnalysis,
        catalog: [CodeforcesProblem]
    ) -> [WeakTopicRecommendation] {
        let solvedProblemIDs = analysis.solvedProblemIDs
        let targetRating = analysis.effectiveCurrentRating
        let window = max(800, targetRating - 200)...min(3500, targetRating + 100)

        return weakTopics.prefix(3).compactMap { weakTopic in
            let preferredTags = Set([weakTopic.topic.tag.lowercased()])
            let candidates = SuggestedProblemsViewModel.filterCandidates(
                from: catalog,
                solvedProblemIDs: solvedProblemIDs,
                ratingWindow: window,
                preferredTags: preferredTags
            )

            let rankedProblems = SuggestedProblemsViewModel.rankCandidates(candidates, targetRating: targetRating)
                .prefix(2)
                .map(\.problem)

            guard !rankedProblems.isEmpty else { return nil }

            return WeakTopicRecommendation(
                weakTopic: weakTopic,
                problems: rankedProblems
            )
        }
    }
}

@MainActor
final class RoadmapViewModel: ObservableObject {
    @Published private(set) var analysis: HandleAnalysis?
    @Published private(set) var highlightedStage: RoadmapStage = RoadmapStage.all[0]
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    private let analysisService: CodeforcesAnalysisService

    init(analysisService: CodeforcesAnalysisService = .shared) {
        self.analysisService = analysisService
    }

    func load(for handle: String) async {
        let trimmedHandle = handle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedHandle.isEmpty else {
            highlightedStage = RoadmapStage.all[0]
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            let analysis = try await analysisService.loadAnalysis(for: trimmedHandle)
            self.analysis = analysis
            highlightedStage = RoadmapStage.stage(for: analysis.effectiveCurrentRating)
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}
