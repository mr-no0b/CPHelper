import Foundation

enum CodeforcesError: LocalizedError {
    case invalidHandle
    case invalidURL
    case invalidResponse
    case emptyResponse
    case apiFailure(String)

    var errorDescription: String? {
        switch self {
        case .invalidHandle:
            return "Enter a valid Codeforces handle."
        case .invalidURL:
            return "Could not create the Codeforces request."
        case .invalidResponse:
            return "Received an unexpected response from Codeforces."
        case .emptyResponse:
            return "No public Codeforces data was returned for this handle."
        case .apiFailure(let message):
            return message
        }
    }
}

actor CodeforcesAnalysisService {
    static let shared = CodeforcesAnalysisService()

    private struct CodeforcesEnvelope<ResultType: Decodable>: Decodable {
        let status: String
        let comment: String?
        let result: ResultType?
    }

    private struct CFUser: Decodable {
        let handle: String
        let firstName: String?
        let lastName: String?
        let rank: String?
        let maxRank: String?
        let rating: Int?
        let maxRating: Int?
        let avatar: String?
        let titlePhoto: String?
    }

    private struct CFRatingChange: Decodable {
        let contestId: Int
        let contestName: String
    }

    private struct CFContest: Decodable {
        let id: Int
        let name: String
    }

    private struct CFSubmission: Decodable {
        let id: Int
        let contestId: Int?
        let creationTimeSeconds: Int
        let verdict: String?
        let problem: CFProblem
        let author: CFParty?
    }

    private struct CFProblem: Decodable {
        let contestId: Int?
        let index: String?
        let name: String
        let rating: Int?
        let tags: [String]?
    }

    private struct CFParty: Decodable {
        let participantType: String?
    }

    private struct ProblemKey: Hashable {
        let contestId: Int?
        let index: String?
        let name: String
    }

    private let session: URLSession
    private let decoder = JSONDecoder()

    private var lastRequestTime: Date?
    private var contestNameCache: [Int: String]?
    private var analysisCache: [String: HandleAnalysis] = [:]

    init(session: URLSession = .shared) {
        self.session = session
    }

    func loadAnalysis(for rawHandle: String, forceRefresh: Bool = false) async throws -> HandleAnalysis {
        let handle = rawHandle.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !handle.isEmpty else {
            throw CodeforcesError.invalidHandle
        }

        let cacheKey = handle.lowercased()
        if let cached = analysisCache[cacheKey], !forceRefresh {
            return cached
        }

        let users: [CFUser] = try await request(
            method: "user.info",
            queryItems: [
                URLQueryItem(name: "handles", value: handle),
                URLQueryItem(name: "checkHistoricHandles", value: "true")
            ]
        )

        guard let user = users.first else {
            throw CodeforcesError.emptyResponse
        }

        let ratingChanges: [CFRatingChange] = try await request(
            method: "user.rating",
            queryItems: [URLQueryItem(name: "handle", value: handle)]
        )

        let submissions: [CFSubmission] = try await request(
            method: "user.status",
            queryItems: [URLQueryItem(name: "handle", value: handle)]
        )

        let contestNames = try await loadContestNames()
        let analysis = buildAnalysis(
            user: user,
            ratingChanges: ratingChanges,
            submissions: submissions,
            contestNames: contestNames
        )

        analysisCache[cacheKey] = analysis
        return analysis
    }

    private func loadContestNames() async throws -> [Int: String] {
        if let contestNameCache {
            return contestNameCache
        }

        let contests: [CFContest] = try await request(
            method: "contest.list",
            queryItems: [URLQueryItem(name: "gym", value: "false")]
        )

        let mappedNames = Dictionary(uniqueKeysWithValues: contests.map { ($0.id, $0.name) })
        contestNameCache = mappedNames
        return mappedNames
    }

    private func request<ResponseType: Decodable>(
        method: String,
        queryItems: [URLQueryItem]
    ) async throws -> ResponseType {
        try await throttleRequests()

        guard var components = URLComponents(string: "https://codeforces.com/api/\(method)") else {
            throw CodeforcesError.invalidURL
        }

        components.queryItems = queryItems + [URLQueryItem(name: "lang", value: "en")]

        guard let url = components.url else {
            throw CodeforcesError.invalidURL
        }

        let (data, response) = try await session.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse, 200..<300 ~= httpResponse.statusCode else {
            throw CodeforcesError.invalidResponse
        }

        let envelope = try decoder.decode(CodeforcesEnvelope<ResponseType>.self, from: data)

        guard envelope.status == "OK" else {
            throw CodeforcesError.apiFailure(envelope.comment ?? "Codeforces returned an error.")
        }

        guard let result = envelope.result else {
            throw CodeforcesError.emptyResponse
        }

        return result
    }

    private func throttleRequests() async throws {
        let minimumDelay = 2.15

        if let lastRequestTime {
            let elapsed = Date().timeIntervalSince(lastRequestTime)
            if elapsed < minimumDelay {
                let sleepNanoseconds = UInt64((minimumDelay - elapsed) * 1_000_000_000)
                try await Task.sleep(nanoseconds: sleepNanoseconds)
            }
        }

        lastRequestTime = Date()
    }

    private func buildAnalysis(
        user: CFUser,
        ratingChanges: [CFRatingChange],
        submissions: [CFSubmission],
        contestNames: [Int: String]
    ) -> HandleAnalysis {
        let sortedSubmissions = submissions.sorted { $0.creationTimeSeconds < $1.creationTimeSeconds }
        let acceptedSubmissions = sortedSubmissions.filter {
            SubmissionVerdict(rawVerdict: $0.verdict) == .accepted
        }

        var solvedProblems: [ProblemKey: CFSubmission] = [:]
        for submission in acceptedSubmissions {
            let key = ProblemKey(
                contestId: submission.problem.contestId ?? submission.contestId,
                index: submission.problem.index,
                name: submission.problem.name
            )

            if solvedProblems[key] == nil {
                solvedProblems[key] = submission
            }
        }

        let solvedProblemValues = Array(solvedProblems.values)
        let acceptedCount = acceptedSubmissions.count
        let totalSubmissions = sortedSubmissions.count
        let overallAcceptanceRate = totalSubmissions > 0
            ? Double(acceptedCount) / Double(totalSubmissions)
            : 0

        let verdicts = buildVerdictSlices(from: sortedSubmissions)
        let solvedByRating = buildSolvedByRating(
            solvedSubmissions: solvedProblemValues,
            allSubmissions: sortedSubmissions
        )
        let acceptanceByRating = buildAcceptanceByRating(
            solvedSubmissions: solvedProblemValues,
            allSubmissions: sortedSubmissions
        )
        let roundTypePerformance = buildRoundTypePerformance(
            submissions: sortedSubmissions,
            ratingChanges: ratingChanges,
            contestNames: contestNames
        )
        let topicPerformance = buildTopicPerformance(
            solvedSubmissions: solvedProblemValues,
            allSubmissions: sortedSubmissions
        )
        let monthlyActivity = buildMonthlyActivity(from: sortedSubmissions)
        let highestSolvedRating = solvedProblemValues.compactMap(\.problem.rating).max()
        let mostProductiveTag = topicPerformance.max {
            if $0.solvedCount == $1.solvedCount {
                return $0.acceptanceRate < $1.acceptanceRate
            }
            return $0.solvedCount < $1.solvedCount
        }?.tag

        let summary = HandleAnalysisSummary(
            displayName: [user.firstName, user.lastName]
                .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .joined(separator: " ")
                .ifEmpty(user.handle),
            currentRating: user.rating,
            maxRating: user.maxRating,
            rankTitle: user.rank,
            maxRankTitle: user.maxRank,
            solvedCount: solvedProblemValues.count,
            totalSubmissions: totalSubmissions,
            acceptedSubmissions: acceptedCount,
            overallAcceptanceRate: overallAcceptanceRate,
            contestsParticipated: Set(ratingChanges.map(\.contestId)).count,
            highestSolvedRating: highestSolvedRating,
            mostProductiveTag: mostProductiveTag,
            lastActiveDate: sortedSubmissions.last.map {
                Date(timeIntervalSince1970: TimeInterval($0.creationTimeSeconds))
            },
            avatarURL: URL(string: user.titlePhoto ?? user.avatar ?? "")
        )

        let strengths = buildStrengths(
            summary: summary,
            topicPerformance: topicPerformance,
            roundTypePerformance: roundTypePerformance
        )
        let weaknesses = buildWeaknesses(
            summary: summary,
            acceptanceByRating: acceptanceByRating,
            topicPerformance: topicPerformance,
            roundTypePerformance: roundTypePerformance
        )

        return HandleAnalysis(
            handle: user.handle,
            fetchedAt: .now,
            summary: summary,
            verdicts: verdicts,
            solvedByRating: solvedByRating,
            acceptanceByRating: acceptanceByRating,
            roundTypePerformance: roundTypePerformance,
            strengths: strengths,
            weaknesses: weaknesses,
            topicPerformance: topicPerformance,
            monthlyActivity: monthlyActivity
        )
    }

    private func buildVerdictSlices(from submissions: [CFSubmission]) -> [VerdictSlice] {
        guard !submissions.isEmpty else { return [] }

        let groupedVerdicts = Dictionary(
            grouping: submissions.map { SubmissionVerdict(rawVerdict: $0.verdict) },
            by: { $0 }
        )

        return groupedVerdicts.map { verdict, items in
            VerdictSlice(
                verdict: verdict,
                count: items.count,
                share: Double(items.count) / Double(submissions.count)
            )
        }
        .sorted { lhs, rhs in
            if lhs.count == rhs.count {
                return lhs.verdict.title < rhs.verdict.title
            }
            return lhs.count > rhs.count
        }
    }

    private func buildSolvedByRating(
        solvedSubmissions: [CFSubmission],
        allSubmissions: [CFSubmission]
    ) -> [RatingPerformance] {
        buildRatingPerformance(
            solvedSubmissions: solvedSubmissions,
            allSubmissions: allSubmissions,
            includeUnrated: false
        )
    }

    private func buildAcceptanceByRating(
        solvedSubmissions: [CFSubmission],
        allSubmissions: [CFSubmission]
    ) -> [RatingPerformance] {
        buildRatingPerformance(
            solvedSubmissions: solvedSubmissions,
            allSubmissions: allSubmissions,
            includeUnrated: true
        )
    }

    private func buildRatingPerformance(
        solvedSubmissions: [CFSubmission],
        allSubmissions: [CFSubmission],
        includeUnrated: Bool
    ) -> [RatingPerformance] {
        var ratings = Set(allSubmissions.compactMap(\.problem.rating))
        ratings.formUnion(solvedSubmissions.compactMap(\.problem.rating))
        let sortedRatings = ratings.sorted()

        var performance = sortedRatings.map { ratingValue in
            let matchingSubmissions = allSubmissions.filter { $0.problem.rating == ratingValue }
            let acceptedCount = matchingSubmissions.filter {
                SubmissionVerdict(rawVerdict: $0.verdict) == .accepted
            }.count
            let solvedCount = solvedSubmissions.filter { $0.problem.rating == ratingValue }.count

            return RatingPerformance(
                label: "\(ratingValue)",
                ratingValue: ratingValue,
                solvedCount: solvedCount,
                submissionCount: matchingSubmissions.count,
                acceptedCount: acceptedCount,
                acceptanceRate: matchingSubmissions.isEmpty
                    ? 0
                    : Double(acceptedCount) / Double(matchingSubmissions.count)
            )
        }

        if includeUnrated {
            let unratedSubmissions = allSubmissions.filter { $0.problem.rating == nil }
            if !unratedSubmissions.isEmpty {
                let acceptedCount = unratedSubmissions.filter {
                    SubmissionVerdict(rawVerdict: $0.verdict) == .accepted
                }.count
                let solvedCount = solvedSubmissions.filter { $0.problem.rating == nil }.count

                performance.append(
                    RatingPerformance(
                        label: "Unrated",
                        ratingValue: nil,
                        solvedCount: solvedCount,
                        submissionCount: unratedSubmissions.count,
                        acceptedCount: acceptedCount,
                        acceptanceRate: Double(acceptedCount) / Double(unratedSubmissions.count)
                    )
                )
            }
        }

        return performance
    }

    private func buildRoundTypePerformance(
        submissions: [CFSubmission],
        ratingChanges: [CFRatingChange],
        contestNames: [Int: String]
    ) -> [RoundTypePerformance] {
        let ratingChangeContestNames = Dictionary(uniqueKeysWithValues: ratingChanges.map { ($0.contestId, $0.contestName) })

        let contestSubmissions = submissions.filter {
            guard let participantType = $0.author?.participantType else { return false }

            switch participantType {
            case "CONTESTANT", "OUT_OF_COMPETITION", "VIRTUAL":
                return true
            default:
                return false
            }
        }

        let groupedByRoundType = Dictionary(grouping: contestSubmissions) { submission in
            let contestName = submission.contestId.flatMap { ratingChangeContestNames[$0] ?? contestNames[$0] } ?? ""
            return classifyRoundType(contestName: contestName)
        }

        return groupedByRoundType.map { roundType, entries in
            let contestCount = Set(entries.compactMap(\.contestId)).count
            let acceptedCount = entries.filter {
                SubmissionVerdict(rawVerdict: $0.verdict) == .accepted
            }.count

            return RoundTypePerformance(
                roundType: roundType,
                contestCount: contestCount,
                submissionCount: entries.count,
                acceptedCount: acceptedCount,
                acceptanceRate: entries.isEmpty ? 0 : Double(acceptedCount) / Double(entries.count)
            )
        }
        .sorted { lhs, rhs in
            if lhs.contestCount == rhs.contestCount {
                return lhs.acceptanceRate > rhs.acceptanceRate
            }
            return lhs.contestCount > rhs.contestCount
        }
    }

    private func buildTopicPerformance(
        solvedSubmissions: [CFSubmission],
        allSubmissions: [CFSubmission]
    ) -> [TopicPerformance] {
        var attemptedBuckets: [String: [CFSubmission]] = [:]

        for submission in allSubmissions {
            for tag in submission.problem.tags ?? [] {
                attemptedBuckets[tag, default: []].append(submission)
            }
        }

        let solvedProblemKeys = Dictionary(
            grouping: solvedSubmissions,
            by: { ProblemKey(contestId: $0.problem.contestId ?? $0.contestId, index: $0.problem.index, name: $0.problem.name) }
        )

        let solvedBuckets = solvedProblemKeys.values.flatMap { problemAttempts -> [(String, ProblemKey)] in
            guard let solvedSubmission = problemAttempts.first else { return [] }
            let key = ProblemKey(
                contestId: solvedSubmission.problem.contestId ?? solvedSubmission.contestId,
                index: solvedSubmission.problem.index,
                name: solvedSubmission.problem.name
            )
            return (solvedSubmission.problem.tags ?? []).map { ($0, key) }
        }

        let solvedCountByTag = Dictionary(grouping: solvedBuckets, by: { $0.0 }).mapValues { buckets in
            Set(buckets.map { $0.1 }).count
        }

        return attemptedBuckets.map { tag, attempts in
            let acceptedCount = attempts.filter {
                SubmissionVerdict(rawVerdict: $0.verdict) == .accepted
            }.count

            return TopicPerformance(
                tag: tag,
                solvedCount: solvedCountByTag[tag] ?? 0,
                attemptedCount: attempts.count,
                acceptedCount: acceptedCount,
                acceptanceRate: attempts.isEmpty ? 0 : Double(acceptedCount) / Double(attempts.count)
            )
        }
        .sorted { lhs, rhs in
            if lhs.solvedCount == rhs.solvedCount {
                if lhs.attemptedCount == rhs.attemptedCount {
                    return lhs.tag < rhs.tag
                }
                return lhs.attemptedCount > rhs.attemptedCount
            }
            return lhs.solvedCount > rhs.solvedCount
        }
    }

    private func buildMonthlyActivity(from submissions: [CFSubmission]) -> [MonthlyActivity] {
        guard !submissions.isEmpty else { return [] }

        let calendar = Calendar(identifier: .gregorian)
        let now = Date()
        let currentMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) ?? now

        let monthStarts = (0..<6).compactMap { offset in
            calendar.date(byAdding: .month, value: -offset, to: currentMonth)
        }.reversed()

        return monthStarts.map { monthStart in
            let monthComponents = calendar.dateComponents([.year, .month], from: monthStart)
            let entries = submissions.filter { submission in
                let date = Date(timeIntervalSince1970: TimeInterval(submission.creationTimeSeconds))
                let submissionComponents = calendar.dateComponents([.year, .month], from: date)
                return submissionComponents.year == monthComponents.year
                    && submissionComponents.month == monthComponents.month
            }

            let acceptedCount = entries.filter {
                SubmissionVerdict(rawVerdict: $0.verdict) == .accepted
            }.count

            return MonthlyActivity(
                monthLabel: DateFormatting.shortMonthYear.string(from: monthStart),
                submissionCount: entries.count,
                acceptedCount: acceptedCount
            )
        }
    }

    private func buildStrengths(
        summary: HandleAnalysisSummary,
        topicPerformance: [TopicPerformance],
        roundTypePerformance: [RoundTypePerformance]
    ) -> [AnalysisInsight] {
        var insights: [AnalysisInsight] = []

        if let standoutTag = topicPerformance.first(where: { $0.solvedCount >= 3 && $0.acceptanceRate >= summary.overallAcceptanceRate + 0.12 }) {
            insights.append(
                AnalysisInsight(
                    title: "Strong in \(standoutTag.tag)",
                    detail: "\(NumberFormatting.percentage(standoutTag.acceptanceRate)) acceptance across \(standoutTag.attemptedCount) tagged submissions with \(standoutTag.solvedCount) solved problems.",
                    tone: .positive
                )
            )
        }

        if let highestSolvedRating = summary.highestSolvedRating,
           let currentRating = summary.currentRating,
           highestSolvedRating >= currentRating + 200 {
            insights.append(
                AnalysisInsight(
                    title: "Problem ceiling is ahead of current rating",
                    detail: "You have already solved up to rating \(highestSolvedRating), which is comfortably above the current rating of \(currentRating).",
                    tone: .positive
                )
            )
        }

        if let bestRound = roundTypePerformance
            .filter({ $0.contestCount >= 2 })
            .max(by: { $0.acceptanceRate < $1.acceptanceRate }) {
            insights.append(
                AnalysisInsight(
                    title: "\(bestRound.roundType.rawValue) rounds suit you well",
                    detail: "\(NumberFormatting.percentage(bestRound.acceptanceRate)) acceptance rate over \(bestRound.contestCount) contests suggests strong contest comfort there.",
                    tone: .positive
                )
            )
        }

        if insights.isEmpty {
            insights.append(
                AnalysisInsight(
                    title: "Healthy base to build on",
                    detail: "This handle already has accepted solutions and contest history, so there is enough signal to keep refining rating-wise practice.",
                    tone: .positive
                )
            )
        }

        return Array(insights.prefix(3))
    }

    private func buildWeaknesses(
        summary: HandleAnalysisSummary,
        acceptanceByRating: [RatingPerformance],
        topicPerformance: [TopicPerformance],
        roundTypePerformance: [RoundTypePerformance]
    ) -> [AnalysisInsight] {
        var insights: [AnalysisInsight] = []

        if let strugglingTag = topicPerformance.first(where: {
            $0.attemptedCount >= 5 && $0.acceptanceRate <= max(summary.overallAcceptanceRate - 0.15, 0.15)
        }) {
            insights.append(
                AnalysisInsight(
                    title: "Weak spot around \(strugglingTag.tag)",
                    detail: "Only \(NumberFormatting.percentage(strugglingTag.acceptanceRate)) acceptance over \(strugglingTag.attemptedCount) submissions suggests this topic needs more deliberate practice.",
                    tone: .caution
                )
            )
        }

        if let ratingBand = acceptanceByRating
            .filter({ $0.ratingValue != nil && $0.submissionCount >= 4 })
            .min(by: { $0.acceptanceRate < $1.acceptanceRate }) {
            insights.append(
                AnalysisInsight(
                    title: "Conversion drops around rating \(ratingBand.label)",
                    detail: "This band has only \(NumberFormatting.percentage(ratingBand.acceptanceRate)) acceptance across \(ratingBand.submissionCount) submissions.",
                    tone: .caution
                )
            )
        }

        if let toughestRound = roundTypePerformance
            .filter({ $0.contestCount >= 2 })
            .min(by: { $0.acceptanceRate < $1.acceptanceRate }) {
            insights.append(
                AnalysisInsight(
                    title: "\(toughestRound.roundType.rawValue) contests need more work",
                    detail: "Round pressure is visible here with \(NumberFormatting.percentage(toughestRound.acceptanceRate)) acceptance across \(toughestRound.contestCount) contests.",
                    tone: .caution
                )
            )
        }

        if insights.isEmpty {
            insights.append(
                AnalysisInsight(
                    title: "Next step is sharper volume",
                    detail: "There is no single obvious weak tag yet, so increasing focused attempts around your next rating band should surface the next growth edge.",
                    tone: .neutral
                )
            )
        }

        return Array(insights.prefix(3))
    }

    private func classifyRoundType(contestName: String) -> ContestRoundType {
        let normalized = contestName.lowercased()

        if normalized.contains("educational") {
            return .educational
        }

        if normalized.contains("div. 1 + div. 2")
            || normalized.contains("div. 1+2")
            || normalized.contains("div.1 + div.2")
            || normalized.contains("div 1 + div 2")
        {
            return .div12
        }

        if normalized.contains("div. 1") || normalized.contains("div 1") {
            return .div1
        }

        if normalized.contains("div. 2") || normalized.contains("div 2") {
            return .div2
        }

        if normalized.contains("div. 3")
            || normalized.contains("div 3")
            || normalized.contains("div. 4")
            || normalized.contains("div 4")
        {
            return .div3
        }

        return .global
    }
}

private extension String {
    func ifEmpty(_ fallback: @autoclosure () -> String) -> String {
        isEmpty ? fallback() : self
    }
}
