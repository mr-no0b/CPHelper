import Foundation

actor TutorialCatalogService {
    static let shared = TutorialCatalogService()

    private struct CachedTutorialList: Codable {
        let fetchedAt: Date
        let tutorials: [AlgorithmTutorial]
    }

    private struct CachedTutorialDetail: Codable {
        let fetchedAt: Date
        let detail: AlgorithmTutorialDetail
    }

    private let session: URLSession
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let fileManager = FileManager.default
    private let cacheLifetime: TimeInterval = 60 * 60 * 24

    private var listMemoryCache: CachedTutorialList?
    private var detailMemoryCache: [String: CachedTutorialDetail] = [:]

    init(session: URLSession = .shared) {
        self.session = session

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    func loadTutorials(forceRefresh: Bool = false) async throws -> [AlgorithmTutorial] {
        if let listMemoryCache, !forceRefresh, isFresh(listMemoryCache.fetchedAt) {
            return listMemoryCache.tutorials
        }

        let diskCache = try? loadListDiskCache()
        if let diskCache, !forceRefresh, isFresh(diskCache.fetchedAt) {
            listMemoryCache = diskCache
            return diskCache.tutorials
        }

        do {
            let tutorials = try await fetchTutorials()
            let cached = CachedTutorialList(fetchedAt: .now, tutorials: tutorials)
            listMemoryCache = cached
            try? saveListDiskCache(cached)
            return tutorials
        } catch {
            if let diskCache {
                listMemoryCache = diskCache
                return diskCache.tutorials
            }

            throw error
        }
    }

    func loadDetail(for tutorial: AlgorithmTutorial, forceRefresh: Bool = false) async throws -> AlgorithmTutorialDetail {
        if let detailMemoryCache = detailMemoryCache[tutorial.id], !forceRefresh, isFresh(detailMemoryCache.fetchedAt) {
            return detailMemoryCache.detail
        }

        let diskCache = try? loadDetailDiskCache(for: tutorial.id)
        if let diskCache, !forceRefresh, isFresh(diskCache.fetchedAt) {
            detailMemoryCache[tutorial.id] = diskCache
            return diskCache.detail
        }

        do {
            let detail = try await fetchDetail(for: tutorial)
            let cached = CachedTutorialDetail(fetchedAt: .now, detail: detail)
            detailMemoryCache[tutorial.id] = cached
            try? saveDetailDiskCache(cached, for: tutorial.id)
            return detail
        } catch {
            if let diskCache {
                detailMemoryCache[tutorial.id] = diskCache
                return diskCache.detail
            }

            throw error
        }
    }

    private func fetchTutorials() async throws -> [AlgorithmTutorial] {
        guard let url = URL(string: "https://cp-algorithms.com/") else {
            throw CodeforcesError.invalidURL
        }

        let html = try await downloadString(from: url)
        let regex = try NSRegularExpression(
            pattern: #"<a\s+href="([^"]+\.html)"[^>]*>(.*?)</a>"#,
            options: [.caseInsensitive, .dotMatchesLineSeparators]
        )

        let matches = regex.matches(
            in: html,
            range: NSRange(location: 0, length: html.utf16.count)
        )

        var seenPaths: Set<String> = []
        var tutorials: [AlgorithmTutorial] = []

        for match in matches {
            guard match.numberOfRanges >= 3,
                  let pathRange = Range(match.range(at: 1), in: html),
                  let titleRange = Range(match.range(at: 2), in: html) else {
                continue
            }

            var path = String(html[pathRange])
            path = path.trimmingCharacters(in: .whitespacesAndNewlines)
            path = path.replacingOccurrences(of: "./", with: "")
            path = path.replacingOccurrences(of: "../", with: "")

            if let absoluteURL = URL(string: path), absoluteURL.scheme != nil {
                guard absoluteURL.host?.contains("cp-algorithms.com") == true else {
                    continue
                }

                path = absoluteURL.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            }

            guard shouldInclude(path: path), !seenPaths.contains(path) else {
                continue
            }

            let rawTitle = String(html[titleRange])
            let title = decodeHTMLEntities(stripHTML(rawTitle)).trimmingCharacters(in: .whitespacesAndNewlines)
            let resolvedTitle = title.isEmpty ? titleFromPath(path) : title
            let category = categoryTitle(from: path)
            let level = estimatedLevel(for: resolvedTitle, category: category)

            let tutorial = AlgorithmTutorial(
                id: path.replacingOccurrences(of: ".html", with: ""),
                title: resolvedTitle,
                explanation: summary(for: resolvedTitle, category: category),
                difficulty: level,
                practiceTip: practiceTip(for: category),
                category: category,
                sourcePath: path,
                sourceURLString: "https://cp-algorithms.com/\(path)",
                sourceMarkdownURLString: "https://raw.githubusercontent.com/cp-algorithms/cp-algorithms/main/src/\(markdownPath(from: path))"
            )

            seenPaths.insert(path)
            tutorials.append(tutorial)
        }

        return tutorials.sorted { lhs, rhs in
            if lhs.category == rhs.category {
                return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
            }

            return lhs.category.localizedCaseInsensitiveCompare(rhs.category) == .orderedAscending
        }
    }

    private func fetchDetail(for tutorial: AlgorithmTutorial) async throws -> AlgorithmTutorialDetail {
        let markdownURL = tutorial.sourceMarkdownURL
            ?? URL(string: "https://raw.githubusercontent.com/cp-algorithms/cp-algorithms/main/src/\(markdownPath(from: tutorial.sourcePath))")

        guard let markdownURL else {
            throw CodeforcesError.invalidURL
        }

        let rawMarkdown = try await downloadString(from: markdownURL)
        let cleanedMarkdown = stripFrontMatter(from: rawMarkdown)
        let lines = cleanedMarkdown.components(separatedBy: .newlines)

        var overviewParagraphs: [String] = []
        var sectionHeadings: [String] = []
        var practiceLinks: [TutorialResourceLink] = []
        var relatedLinks: [TutorialResourceLink] = []
        var currentParagraph: [String] = []
        var currentSection = ""
        var passedTitle = false

        for rawLine in lines {
            let line = rawLine.trimmingCharacters(in: .whitespaces)

            if line.hasPrefix("# ") {
                passedTitle = true
                continue
            }

            if line.hasPrefix("## ") {
                flushParagraph(into: &overviewParagraphs, buffer: &currentParagraph)
                currentSection = String(line.dropFirst(3)).trimmingCharacters(in: .whitespacesAndNewlines)
                sectionHeadings.append(stripMarkdownSyntax(currentSection))
                continue
            }

            if line.hasPrefix("### ") {
                continue
            }

            if isBulletLink(line), let link = parseMarkdownLink(from: line, tutorial: tutorial) {
                let normalizedSection = currentSection.lowercased()
                if normalizedSection.contains("practice") || normalizedSection.contains("contest") {
                    practiceLinks.append(link)
                } else if normalizedSection.contains("related") {
                    relatedLinks.append(link)
                }
            }

            guard passedTitle else { continue }

            if currentSection.isEmpty {
                if line.isEmpty {
                    flushParagraph(into: &overviewParagraphs, buffer: &currentParagraph)
                } else if !line.hasPrefix("```") && !line.hasPrefix("|") {
                    currentParagraph.append(line)
                }
            }
        }

        flushParagraph(into: &overviewParagraphs, buffer: &currentParagraph)

        let dedupedPracticeLinks = dedupe(links: practiceLinks)
        let dedupedRelatedLinks = dedupe(links: relatedLinks)
        let wordCount = cleanedMarkdown.split { $0.isWhitespace || $0.isNewline }.count
        let readingMinutes = max(4, Int(ceil(Double(wordCount) / 220.0)))

        return AlgorithmTutorialDetail(
            tutorial: tutorial,
            overviewParagraphs: Array(overviewParagraphs.prefix(4)),
            sectionHeadings: Array(sectionHeadings.prefix(12)),
            practiceLinks: dedupedPracticeLinks,
            relatedLinks: dedupedRelatedLinks,
            readingMinutes: readingMinutes
        )
    }

    private func flushParagraph(into paragraphs: inout [String], buffer: inout [String]) {
        guard !buffer.isEmpty else { return }

        let paragraph = stripMarkdownSyntax(buffer.joined(separator: " "))
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if !paragraph.isEmpty {
            paragraphs.append(paragraph)
        }

        buffer.removeAll()
    }

    private func shouldInclude(path: String) -> Bool {
        guard path.contains("/"), path.hasSuffix(".html") else { return false }

        let blockedPaths: Set<String> = [
            "index.html",
            "navigation.html",
            "tags.html",
            "contrib.html",
            "preview.html",
            "code_of_conduct.html"
        ]

        return !blockedPaths.contains(path)
    }

    private func markdownPath(from htmlPath: String) -> String {
        htmlPath.replacingOccurrences(of: ".html", with: ".md")
    }

    private func titleFromPath(_ path: String) -> String {
        path
            .components(separatedBy: "/")
            .last?
            .replacingOccurrences(of: ".html", with: "")
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "_", with: " ")
            .split(separator: " ")
            .map { $0.capitalized }
            .joined(separator: " ") ?? "Tutorial"
    }

    private func categoryTitle(from path: String) -> String {
        let rawCategory = path.components(separatedBy: "/").first ?? "algorithms"
        return rawCategory
            .replacingOccurrences(of: "_", with: " ")
            .split(separator: " ")
            .map { $0.capitalized }
            .joined(separator: " ")
    }

    private func estimatedLevel(for title: String, category: String) -> String {
        let loweredTitle = title.lowercased()
        let loweredCategory = category.lowercased()

        if loweredTitle.contains("suffix")
            || loweredTitle.contains("flow")
            || loweredTitle.contains("fft")
            || loweredTitle.contains("tree")
            || loweredTitle.contains("geometry")
            || loweredTitle.contains("matching")
            || loweredCategory.contains("geometry")
            || loweredCategory.contains("string")
            || loweredCategory.contains("graph") {
            return "Advanced"
        }

        if loweredTitle.contains("intro")
            || loweredTitle.contains("basic")
            || loweredTitle.contains("binary search")
            || loweredTitle.contains("breadth")
            || loweredTitle.contains("depth")
            || loweredCategory.contains("dynamic programming")
            || loweredCategory.contains("data structures") {
            return "Intermediate"
        }

        return "Foundations"
    }

    private func summary(for title: String, category: String) -> String {
        "A \(category.lowercased()) tutorial from cp-algorithms focused on \(title.lowercased())."
    }

    private func practiceTip(for category: String) -> String {
        "Read the key idea, skim the section map, then solve one \(category.lowercased()) problem before moving on."
    }

    private func stripFrontMatter(from markdown: String) -> String {
        guard markdown.hasPrefix("---") else { return markdown }

        let separator = "\n---\n"
        guard let range = markdown.range(of: separator) else { return markdown }
        return String(markdown[range.upperBound...])
    }

    private func stripHTML(_ html: String) -> String {
        html.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
    }

    private func decodeHTMLEntities(_ text: String) -> String {
        var output = text
        let entities = [
            "&amp;": "&",
            "&#39;": "'",
            "&quot;": "\"",
            "&lt;": "<",
            "&gt;": ">",
            "&nbsp;": " "
        ]

        for (entity, replacement) in entities {
            output = output.replacingOccurrences(of: entity, with: replacement)
        }

        return output
    }

    private func stripMarkdownSyntax(_ text: String) -> String {
        var cleaned = text

        if let regex = try? NSRegularExpression(pattern: #"\[(.*?)\]\((.*?)\)"#) {
            let range = NSRange(location: 0, length: cleaned.utf16.count)
            cleaned = regex.stringByReplacingMatches(in: cleaned, options: [], range: range, withTemplate: "$1")
        }

        cleaned = cleaned.replacingOccurrences(of: #"`{1,3}"#, with: "", options: .regularExpression)
        cleaned = cleaned.replacingOccurrences(of: #"[*_>#]"#, with: "", options: .regularExpression)
        cleaned = cleaned.replacingOccurrences(of: #"\$\$.*?\$\$"#, with: "", options: .regularExpression)
        cleaned = cleaned.replacingOccurrences(of: #"\$.*?\$"#, with: "", options: .regularExpression)
        cleaned = cleaned.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        return cleaned
    }

    private func isBulletLink(_ line: String) -> Bool {
        let normalized = line.trimmingCharacters(in: .whitespacesAndNewlines)
        return normalized.hasPrefix("* [") || normalized.hasPrefix("- [")
    }

    private func parseMarkdownLink(from line: String, tutorial: AlgorithmTutorial) -> TutorialResourceLink? {
        guard let titleStart = line.firstIndex(of: "["),
              let titleEnd = line[titleStart...].firstIndex(of: "]"),
              let urlStart = line[titleEnd...].firstIndex(of: "("),
              let urlEnd = line[urlStart...].firstIndex(of: ")") else {
            return nil
        }

        let title = String(line[line.index(after: titleStart)..<titleEnd])
        let rawURL = String(line[line.index(after: urlStart)..<urlEnd])

        guard let resolvedURL = resolveLink(rawURL, tutorial: tutorial) else {
            return nil
        }

        return TutorialResourceLink(title: stripMarkdownSyntax(title), url: resolvedURL)
    }

    private func resolveLink(_ rawURL: String, tutorial: AlgorithmTutorial) -> URL? {
        if let absoluteURL = URL(string: rawURL), absoluteURL.scheme != nil {
            return absoluteURL
        }

        if rawURL.hasSuffix(".md") {
            let htmlPath = rawURL
                .replacingOccurrences(of: "../", with: "")
                .replacingOccurrences(of: ".md", with: ".html")

            return URL(string: "https://cp-algorithms.com/\(htmlPath)")
        }

        guard let sourceURL = tutorial.sourceURL else { return nil }
        return URL(string: rawURL, relativeTo: sourceURL)?.absoluteURL
    }

    private func dedupe(links: [TutorialResourceLink]) -> [TutorialResourceLink] {
        var seen: Set<String> = []
        return links.filter { link in
            let key = "\(link.title.lowercased())::\(link.url.absoluteString)"
            guard !seen.contains(key) else { return false }
            seen.insert(key)
            return true
        }
    }

    private func downloadString(from url: URL) async throws -> String {
        let (data, response) = try await session.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse, 200..<300 ~= httpResponse.statusCode else {
            throw CodeforcesError.invalidResponse
        }

        guard let string = String(data: data, encoding: .utf8) else {
            throw CodeforcesError.emptyResponse
        }

        return string
    }

    private func loadListDiskCache() throws -> CachedTutorialList {
        let data = try Data(contentsOf: listCacheURL())
        return try decoder.decode(CachedTutorialList.self, from: data)
    }

    private func saveListDiskCache(_ cache: CachedTutorialList) throws {
        let data = try encoder.encode(cache)
        try data.write(to: listCacheURL(), options: .atomic)
    }

    private func loadDetailDiskCache(for tutorialID: String) throws -> CachedTutorialDetail {
        let data = try Data(contentsOf: detailCacheURL(for: tutorialID))
        return try decoder.decode(CachedTutorialDetail.self, from: data)
    }

    private func saveDetailDiskCache(_ cache: CachedTutorialDetail, for tutorialID: String) throws {
        let data = try encoder.encode(cache)
        try data.write(to: detailCacheURL(for: tutorialID), options: .atomic)
    }

    private func listCacheURL() throws -> URL {
        try cacheFolderURL().appendingPathComponent("tutorials-list-cache.json")
    }

    private func detailCacheURL(for tutorialID: String) throws -> URL {
        let safeID = tutorialID.replacingOccurrences(of: "/", with: "_")
        return try cacheFolderURL().appendingPathComponent("tutorial-detail-\(safeID).json")
    }

    private func cacheFolderURL() throws -> URL {
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

        return folderURL
    }

    private func isFresh(_ date: Date) -> Bool {
        Date().timeIntervalSince(date) <= cacheLifetime
    }
}
