import Foundation

actor ProfileCacheStore {
    private let fileManager = FileManager.default
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    func save(_ profile: UserProfile) throws {
        let data = try encoder.encode(profile)
        try data.write(to: try cacheURL(for: profile.id), options: .atomic)
    }

    func load(userID: String) throws -> UserProfile? {
        let url = try cacheURL(for: userID)
        guard fileManager.fileExists(atPath: url.path) else { return nil }
        let data = try Data(contentsOf: url)
        return try decoder.decode(UserProfile.self, from: data)
    }

    func remove(userID: String) throws {
        let url = try cacheURL(for: userID)
        guard fileManager.fileExists(atPath: url.path) else { return }
        try fileManager.removeItem(at: url)
    }

    private func cacheURL(for userID: String) throws -> URL {
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

        let safeID = userID.replacingOccurrences(of: "/", with: "_")
        return folderURL.appendingPathComponent("profile-cache-\(safeID).json")
    }
}
