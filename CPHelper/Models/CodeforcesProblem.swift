import Foundation

struct CodeforcesProblem: Codable, Identifiable, Hashable {
    let contestId: Int
    let index: String
    let name: String
    let rating: Int?
    let tags: [String]
    let solvedCount: Int?

    var id: String {
        "\(contestId)-\(index)"
    }

    var displayID: String {
        "\(contestId)\(index)"
    }

    var problemURL: URL {
        URL(string: "https://codeforces.com/problemset/problem/\(contestId)/\(index)")!
    }
}

struct TodoProblem: Codable, Identifiable, Equatable, Hashable {
    let handle: String
    let contestId: Int
    let index: String
    let name: String
    let rating: Int?
    let tags: [String]
    let addedAt: Date

    init(handle: String, problem: CodeforcesProblem, addedAt: Date = .now) {
        self.handle = handle.trimmingCharacters(in: .whitespacesAndNewlines)
        self.contestId = problem.contestId
        self.index = problem.index
        self.name = problem.name
        self.rating = problem.rating
        self.tags = problem.tags
        self.addedAt = addedAt
    }

    var id: String {
        "\(handle.lowercased())::\(contestId)-\(index)"
    }

    var displayID: String {
        "\(contestId)\(index)"
    }

    var problemURL: URL {
        URL(string: "https://codeforces.com/problemset/problem/\(contestId)/\(index)")!
    }

    var asCatalogProblem: CodeforcesProblem {
        CodeforcesProblem(
            contestId: contestId,
            index: index,
            name: name,
            rating: rating,
            tags: tags,
            solvedCount: nil
        )
    }
}
