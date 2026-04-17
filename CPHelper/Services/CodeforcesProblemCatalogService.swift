import Foundation

actor CodeforcesProblemCatalogService {
    static let shared = CodeforcesProblemCatalogService()

    private struct CodeforcesEnvelope<ResultType: Decodable>: Decodable {
        let status: String
        let comment: String?
        let result: ResultType?
    }

    private struct ProblemsetPayload: Decodable {
        let problems: [CFProblem]
        let problemStatistics: [CFProblemStatistics]
    }

    private struct CFProblem: Decodable {
        let contestId: Int?
        let index: String
        let name: String
        let type: String?
        let rating: Int?
        let tags: [String]
    }

    private struct CFProblemStatistics: Decodable {
        let contestId: Int?
        let index: String
        let solvedCount: Int
    }

    private struct CachedProblemset: Codable {
        let fetchedAt: Date
        let problems: [CodeforcesProblem]
    }

    private let session: URLSession
    private let decoder = JSONDecoder()
    private let encoder: JSONEncoder
    private let requestGate: CodeforcesRequestGate
    private let fileManager = FileManager.default
    private let cacheLifetime: TimeInterval = 60 * 60 * 12

    private var memoryCache: CachedProblemset?

    init(
        session: URLSession = .shared,
        requestGate: CodeforcesRequestGate = .shared
    ) {
        self.session = session
        self.requestGate = requestGate

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder

        decoder.dateDecodingStrategy = .iso8601
    }

    func loadProblemset(forceRefresh: Bool = false) async throws -> [CodeforcesProblem] {
        if let memoryCache, !forceRefresh, isFresh(memoryCache.fetchedAt) {
            return memoryCache.problems
        }

        let diskCache = try? loadDiskCache()
        if let diskCache, !forceRefresh, isFresh(diskCache.fetchedAt) {
            memoryCache = diskCache
            return diskCache.problems
        }

        do {
            let fetchedProblems = try await fetchProblemset()
            let cached = CachedProblemset(fetchedAt: .now, problems: fetchedProblems)
            memoryCache = cached
            try? saveDiskCache(cached)
            return fetchedProblems
        } catch {
            if let diskCache {
                memoryCache = diskCache
                return diskCache.problems
            }

            throw error
        }
    }

    private func fetchProblemset() async throws -> [CodeforcesProblem] {
        try await requestGate.waitIfNeeded()

        guard let url = URL(string: "https://codeforces.com/api/problemset.problems?lang=en") else {
            throw CodeforcesError.invalidURL
        }

        let (data, response) = try await session.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse, 200..<300 ~= httpResponse.statusCode else {
            throw CodeforcesError.invalidResponse
        }

        let envelope = try decoder.decode(CodeforcesEnvelope<ProblemsetPayload>.self, from: data)

        guard envelope.status == "OK" else {
            throw CodeforcesError.apiFailure(envelope.comment ?? "Codeforces returned an error.")
        }

        guard let payload = envelope.result else {
            throw CodeforcesError.emptyResponse
        }

        let solvedCounts = Dictionary(uniqueKeysWithValues: payload.problemStatistics.compactMap { statistic in
            guard let contestId = statistic.contestId else { return nil }
            return ("\(contestId)-\(statistic.index)", statistic.solvedCount)
        })

        return payload.problems.compactMap { problem in
            guard let contestId = problem.contestId else { return nil }

            if let type = problem.type, type != "PROGRAMMING" {
                return nil
            }

            return CodeforcesProblem(
                contestId: contestId,
                index: problem.index,
                name: problem.name,
                rating: problem.rating,
                tags: problem.tags,
                solvedCount: solvedCounts["\(contestId)-\(problem.index)"]
            )
        }
        .sorted { lhs, rhs in
            if lhs.rating == rhs.rating {
                if lhs.solvedCount == rhs.solvedCount {
                    return lhs.id < rhs.id
                }
                return (lhs.solvedCount ?? 0) > (rhs.solvedCount ?? 0)
            }
            return (lhs.rating ?? Int.max) < (rhs.rating ?? Int.max)
        }
    }

    private func loadDiskCache() throws -> CachedProblemset {
        let data = try Data(contentsOf: cacheURL())
        return try decoder.decode(CachedProblemset.self, from: data)
    }

    private func saveDiskCache(_ cache: CachedProblemset) throws {
        let data = try encoder.encode(cache)
        try data.write(to: cacheURL(), options: .atomic)
    }

    private func cacheURL() throws -> URL {
        let baseDirectory = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )

        let folderURL = baseDirectory.appendingPathComponent("CPHelper", isDirectory: true)
        if !fileManager.fileExists(atPath: folderURL.path) {
            try fileManager.createDirectory(at: folderURL, withIntermediateDirectories: true, attributes: nil)
        }

        return folderURL.appendingPathComponent("problemset-cache.json")
    }

    private func isFresh(_ date: Date) -> Bool {
        Date().timeIntervalSince(date) <= cacheLifetime
    }
}
