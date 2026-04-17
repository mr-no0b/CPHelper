import Foundation

struct AlgorithmTutorial: Codable, Identifiable, Hashable {
    let id: String
    let title: String
    let explanation: String
    let difficulty: String
    let practiceTip: String
    let category: String
    let sourcePath: String
    let sourceURLString: String
    let sourceMarkdownURLString: String

    init(
        id: String,
        title: String,
        explanation: String,
        difficulty: String,
        practiceTip: String,
        category: String = "Starter",
        sourcePath: String = "",
        sourceURLString: String = "",
        sourceMarkdownURLString: String = ""
    ) {
        self.id = id
        self.title = title
        self.explanation = explanation
        self.difficulty = difficulty
        self.practiceTip = practiceTip
        self.category = category
        self.sourcePath = sourcePath
        self.sourceURLString = sourceURLString
        self.sourceMarkdownURLString = sourceMarkdownURLString
    }

    var sourceURL: URL? {
        URL(string: sourceURLString)
    }

    var sourceMarkdownURL: URL? {
        URL(string: sourceMarkdownURLString)
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case title
        case explanation
        case difficulty
        case practiceTip
        case category
        case sourcePath
        case sourceURLString
        case sourceMarkdownURLString
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        explanation = try container.decodeIfPresent(String.self, forKey: .explanation) ?? "Competitive programming tutorial."
        difficulty = try container.decodeIfPresent(String.self, forKey: .difficulty) ?? "Foundations"
        practiceTip = try container.decodeIfPresent(String.self, forKey: .practiceTip) ?? "Read the concept, then solve a related practice problem."
        category = try container.decodeIfPresent(String.self, forKey: .category) ?? "Starter"
        sourcePath = try container.decodeIfPresent(String.self, forKey: .sourcePath) ?? ""
        sourceURLString = try container.decodeIfPresent(String.self, forKey: .sourceURLString) ?? ""
        sourceMarkdownURLString = try container.decodeIfPresent(String.self, forKey: .sourceMarkdownURLString) ?? ""
    }
}

struct TutorialResourceLink: Codable, Identifiable, Hashable {
    let title: String
    let url: URL

    var id: String {
        title + url.absoluteString
    }
}

struct AlgorithmTutorialDetail: Codable, Hashable {
    let tutorial: AlgorithmTutorial
    let overviewParagraphs: [String]
    let sectionHeadings: [String]
    let practiceLinks: [TutorialResourceLink]
    let relatedLinks: [TutorialResourceLink]
    let readingMinutes: Int
}

extension AlgorithmTutorial {
    static let sample = AlgorithmTutorial(
        id: "binary-search",
        title: "Binary Search",
        explanation: "Binary Search cuts the search space in half each step when the answer range is sorted.",
        difficulty: "Easy",
        practiceTip: "Practice both array search and answer search problems to build confidence.",
        category: "Numerical Methods"
    )
}
