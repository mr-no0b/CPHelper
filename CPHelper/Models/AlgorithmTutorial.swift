import Foundation

struct AlgorithmTutorial: Codable, Identifiable {
    let id: String
    let title: String
    let explanation: String
    let difficulty: String
    let practiceTip: String
}

extension AlgorithmTutorial {
    static let sample = AlgorithmTutorial(
        id: "binary-search",
        title: "Binary Search",
        explanation: "Binary Search cuts the search space in half each step when the answer range is sorted.",
        difficulty: "Easy",
        practiceTip: "Practice both array search and answer search problems to build confidence."
    )
}
