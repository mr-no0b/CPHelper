import Foundation

actor CodeforcesEditorialService {
    static let shared = CodeforcesEditorialService()

    private let session: URLSession
    private var resolvedURLs: [String: URL] = [:]
    private var unavailableProblemIDs: Set<String> = []

    init(session: URLSession = .shared) {
        self.session = session
    }

    func editorialURL(for problem: CodeforcesProblem) async throws -> URL? {
        if let cached = resolvedURLs[problem.id] {
            return cached
        }

        if unavailableProblemIDs.contains(problem.id) {
            return nil
        }

        let (data, response) = try await session.data(from: problem.problemURL)

        guard let httpResponse = response as? HTTPURLResponse, 200..<300 ~= httpResponse.statusCode else {
            throw CodeforcesError.invalidResponse
        }

        let html = String(decoding: data, as: UTF8.self)
        let pattern = #"<a[^>]+href=["']([^"']+)["'][^>]*>\s*Tutorial\s*</a>"#
        let regex = try NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
        let range = NSRange(html.startIndex..<html.endIndex, in: html)

        guard let match = regex.firstMatch(in: html, options: [], range: range),
              let hrefRange = Range(match.range(at: 1), in: html) else {
            unavailableProblemIDs.insert(problem.id)
            return nil
        }

        let rawHref = String(html[hrefRange])
        let resolvedURL: URL?

        if rawHref.hasPrefix("http://") || rawHref.hasPrefix("https://") {
            resolvedURL = URL(string: rawHref)
        } else {
            resolvedURL = URL(string: rawHref, relativeTo: URL(string: "https://codeforces.com"))
                ?.absoluteURL
        }

        guard let resolvedURL else {
            unavailableProblemIDs.insert(problem.id)
            return nil
        }

        resolvedURLs[problem.id] = resolvedURL
        return resolvedURL
    }
}
