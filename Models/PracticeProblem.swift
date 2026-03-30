import Foundation

struct PracticeProblem: Codable, Identifiable, Equatable {
    let id: String
    let name: String
    let rating: Int
    let topic: String
    let isSolved: Bool
}

extension PracticeProblem {
    static let sample = PracticeProblem(
        id: "CF-1368A",
        name: "C+= Problem",
        rating: 900,
        topic: "math",
        isSolved: false
    )
}
