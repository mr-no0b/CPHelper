import Foundation

struct CompetitiveProfile: Codable, Identifiable {
    var id: String { handle }

    let handle: String
    let currentRating: Int
    let maxRating: Int
    let solvedCount: Int
    let strongestTopics: [String]
}

extension CompetitiveProfile {
    static let sample = CompetitiveProfile(
        handle: "tourist",
        currentRating: 3797,
        maxRating: 3826,
        solvedCount: 3941,
        strongestTopics: ["greedy", "dp", "graphs"]
    )
}
