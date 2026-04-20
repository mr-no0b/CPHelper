import Foundation

actor CodeforcesContestService {
    static let shared = CodeforcesContestService()

    private struct CodeforcesEnvelope<ResultType: Decodable>: Decodable {
        let status: String
        let comment: String?
        let result: ResultType?
    }

    private struct CFContest: Decodable {
        let id: Int
        let name: String
        let phase: String
        let type: String?
        let durationSeconds: Int
        let startTimeSeconds: Int?
        let relativeTimeSeconds: Int?
    }

    private struct CachedContestList: Codable {
        let fetchedAt: Date
        let contests: [CodeforcesContest]
    }

    private let session: URLSession
    private let decoder = JSONDecoder()
    private let encoder: JSONEncoder
    private let requestGate: CodeforcesRequestGate
    private let fileManager = FileManager.default
    private let cacheLifetime: TimeInterval = 60 * 30

    private var memoryCache: CachedContestList?

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

    func loadUpcomingContests(forceRefresh: Bool = false) async throws -> [CodeforcesContest] {
        if let memoryCache, !forceRefresh, isFresh(memoryCache.fetchedAt) {
            return memoryCache.contests
        }

        let diskCache = try? loadDiskCache()
        if let diskCache, !forceRefresh, isFresh(diskCache.fetchedAt) {
            memoryCache = diskCache
            return diskCache.contests
        }

        do {
            let fetchedContests = try await fetchUpcomingContests()
            let cached = CachedContestList(fetchedAt: .now, contests: fetchedContests)
            memoryCache = cached
            try? saveDiskCache(cached)
            return fetchedContests
        } catch {
            if let diskCache {
                memoryCache = diskCache
                return diskCache.contests
            }

            let fallbackContests = loadBundleFallbackContests()
            if !fallbackContests.isEmpty {
                let cached = CachedContestList(fetchedAt: .now, contests: fallbackContests)
                memoryCache = cached
                return fallbackContests
            }

            throw error
        }
    }

    private func fetchUpcomingContests() async throws -> [CodeforcesContest] {
        try await requestGate.waitIfNeeded()

        guard let url = URL(string: "https://codeforces.com/api/contest.list?gym=false") else {
            throw CodeforcesError.invalidURL
        }

        let (data, response) = try await session.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse, 200..<300 ~= httpResponse.statusCode else {
            throw CodeforcesError.invalidResponse
        }

        let envelope = try decoder.decode(CodeforcesEnvelope<[CFContest]>.self, from: data)

        guard envelope.status == "OK" else {
            throw CodeforcesError.apiFailure(envelope.comment ?? "Codeforces returned an error.")
        }

        guard let contests = envelope.result else {
            throw CodeforcesError.emptyResponse
        }

        return contests.compactMap { contest in
            guard contest.phase == "BEFORE",
                  let startTimeSeconds = contest.startTimeSeconds else {
                return nil
            }

            return CodeforcesContest(
                id: contest.id,
                name: contest.name,
                phase: contest.phase,
                type: contest.type,
                durationSeconds: contest.durationSeconds,
                startTime: Date(timeIntervalSince1970: TimeInterval(startTimeSeconds)),
                relativeTimeSeconds: contest.relativeTimeSeconds
            )
        }
        .sorted { $0.startTime < $1.startTime }
    }

    private func loadBundleFallbackContests() -> [CodeforcesContest] {
        guard let url = Bundle.main.url(forResource: "contest_fallbacks", withExtension: "json", subdirectory: "Resources")
                ?? Bundle.main.url(forResource: "contest_fallbacks", withExtension: "json") else {
            return []
        }

        guard let data = try? Data(contentsOf: url),
              let contests = try? decoder.decode([CodeforcesContest].self, from: data) else {
            return []
        }

        return contests.sorted { $0.startTime < $1.startTime }
    }

    private func loadDiskCache() throws -> CachedContestList {
        let data = try Data(contentsOf: cacheURL())
        return try decoder.decode(CachedContestList.self, from: data)
    }

    private func saveDiskCache(_ cache: CachedContestList) throws {
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

        return folderURL.appendingPathComponent("contest-cache.json")
    }

    private func isFresh(_ date: Date) -> Bool {
        Date().timeIntervalSince(date) <= cacheLifetime
    }
}
