import Foundation

enum CPChatRole: String, Hashable {
    case user
    case assistant
}

struct CPChatMessage: Identifiable, Hashable {
    let id: UUID
    let role: CPChatRole
    let text: String
    let createdAt: Date

    init(
        id: UUID = UUID(),
        role: CPChatRole,
        text: String,
        createdAt: Date = .now
    ) {
        self.id = id
        self.role = role
        self.text = text
        self.createdAt = createdAt
    }
}

struct ChatHandleInsight: Hashable {
    let handle: String
    let label: String
    let isPrimary: Bool
    let currentRating: Int?
    let maxRating: Int?
    let solvedCount: Int
    let acceptanceRate: Double
    let strengths: [String]
    let weaknesses: [String]
    let roadmapStage: RoadmapStage
}

struct CPChatContextSnapshot {
    let userName: String
    let primaryHandle: String?
    let friends: [FriendProfile]
    let handleInsights: [ChatHandleInsight]
    let currentProblem: CodeforcesProblem?
}

enum ChatNavigationAction: Hashable {
    case handleAnalysis(String)
    case tutorial(String)
    case contestCalendar
}
