import Foundation
import SwiftUI

struct HandleAnalysis: Identifiable, Equatable {
    var id: String { handle.lowercased() }

    let handle: String
    let fetchedAt: Date
    let summary: HandleAnalysisSummary
    let solvedProblems: [HandleSolvedProblem]
    let verdicts: [VerdictSlice]
    let solvedByRating: [RatingPerformance]
    let acceptanceByRating: [RatingPerformance]
    let roundTypePerformance: [RoundTypePerformance]
    let strengths: [AnalysisInsight]
    let weaknesses: [AnalysisInsight]
    let topicPerformance: [TopicPerformance]
    let monthlyActivity: [MonthlyActivity]

    var solvedProblemIDs: Set<String> {
        Set(solvedProblems.map(\.id))
    }

    var effectiveCurrentRating: Int {
        summary.currentRating ?? summary.maxRating ?? 800
    }
}

struct HandleAnalysisSummary: Equatable {
    let displayName: String
    let currentRating: Int?
    let maxRating: Int?
    let rankTitle: String?
    let maxRankTitle: String?
    let solvedCount: Int
    let totalSubmissions: Int
    let acceptedSubmissions: Int
    let overallAcceptanceRate: Double
    let contestsParticipated: Int
    let highestSolvedRating: Int?
    let mostProductiveTag: String?
    let lastActiveDate: Date?
    let avatarURL: URL?
}

struct HandleSolvedProblem: Identifiable, Equatable, Hashable {
    let contestId: Int
    let index: String
    let name: String
    let rating: Int?
    let tags: [String]

    var id: String {
        "\(contestId)-\(index)"
    }
}

struct VerdictSlice: Identifiable, Equatable {
    var id: String { verdict.rawValue }

    let verdict: SubmissionVerdict
    let count: Int
    let share: Double
}

struct RatingPerformance: Identifiable, Equatable {
    var id: String { label }

    let label: String
    let ratingValue: Int?
    let solvedCount: Int
    let submissionCount: Int
    let acceptedCount: Int
    let acceptanceRate: Double
}

struct RoundTypePerformance: Identifiable, Equatable {
    var id: String { roundType.rawValue }

    let roundType: ContestRoundType
    let contestCount: Int
    let submissionCount: Int
    let acceptedCount: Int
    let acceptanceRate: Double
}

struct TopicPerformance: Identifiable, Equatable {
    var id: String { tag }

    let tag: String
    let solvedCount: Int
    let attemptedCount: Int
    let acceptedCount: Int
    let acceptanceRate: Double
}

struct MonthlyActivity: Identifiable, Equatable {
    var id: String { monthLabel }

    let monthLabel: String
    let submissionCount: Int
    let acceptedCount: Int
}

struct AnalysisInsight: Identifiable, Equatable {
    var id: String { title + tone.rawValue }

    let title: String
    let detail: String
    let tone: InsightTone
}

enum InsightTone: String, Equatable {
    case positive
    case caution
    case neutral

    var tint: Color {
        switch self {
        case .positive:
            return AppTheme.success
        case .caution:
            return AppTheme.warning
        case .neutral:
            return AppTheme.accent
        }
    }
}

enum SubmissionVerdict: String, CaseIterable, Equatable {
    case accepted = "OK"
    case wrongAnswer = "WRONG_ANSWER"
    case timeLimit = "TIME_LIMIT_EXCEEDED"
    case memoryLimit = "MEMORY_LIMIT_EXCEEDED"
    case runtimeError = "RUNTIME_ERROR"
    case compilationError = "COMPILATION_ERROR"
    case idlenessLimit = "IDLENESS_LIMIT_EXCEEDED"
    case challenged = "CHALLENGED"
    case rejected = "REJECTED"
    case skipped = "SKIPPED"
    case testing = "TESTING"
    case other = "OTHER"

    init(rawVerdict: String?) {
        switch rawVerdict {
        case "OK":
            self = .accepted
        case "WRONG_ANSWER":
            self = .wrongAnswer
        case "TIME_LIMIT_EXCEEDED":
            self = .timeLimit
        case "MEMORY_LIMIT_EXCEEDED":
            self = .memoryLimit
        case "RUNTIME_ERROR":
            self = .runtimeError
        case "COMPILATION_ERROR":
            self = .compilationError
        case "IDLENESS_LIMIT_EXCEEDED":
            self = .idlenessLimit
        case "CHALLENGED":
            self = .challenged
        case "REJECTED":
            self = .rejected
        case "SKIPPED":
            self = .skipped
        case "TESTING":
            self = .testing
        default:
            self = .other
        }
    }

    var title: String {
        switch self {
        case .accepted:
            return "Accepted"
        case .wrongAnswer:
            return "Wrong Answer"
        case .timeLimit:
            return "Time Limit"
        case .memoryLimit:
            return "Memory Limit"
        case .runtimeError:
            return "Runtime Error"
        case .compilationError:
            return "Compilation Error"
        case .idlenessLimit:
            return "Idleness Limit"
        case .challenged:
            return "Challenged"
        case .rejected:
            return "Rejected"
        case .skipped:
            return "Skipped"
        case .testing:
            return "Testing"
        case .other:
            return "Other"
        }
    }

    var tint: Color {
        switch self {
        case .accepted:
            return AppTheme.success
        case .wrongAnswer:
            return AppTheme.warning
        case .timeLimit:
            return Color(red: 0.88, green: 0.35, blue: 0.28)
        case .memoryLimit:
            return Color(red: 0.63, green: 0.30, blue: 0.81)
        case .runtimeError:
            return Color(red: 0.79, green: 0.20, blue: 0.26)
        case .compilationError:
            return Color(red: 0.42, green: 0.39, blue: 0.87)
        case .idlenessLimit:
            return Color(red: 0.90, green: 0.55, blue: 0.17)
        case .challenged:
            return Color(red: 0.10, green: 0.57, blue: 0.79)
        case .rejected, .skipped, .testing, .other:
            return AppTheme.mutedText
        }
    }
}

enum ContestRoundType: String, CaseIterable, Equatable {
    case div1 = "Div 1"
    case div2 = "Div 2"
    case div12 = "Div 1 + 2"
    case educational = "Educational"
    case div3 = "Div 3 / 4"
    case global = "Global / Other"

    var tint: Color {
        switch self {
        case .div1:
            return Color(red: 0.90, green: 0.33, blue: 0.27)
        case .div2:
            return Color(red: 0.23, green: 0.49, blue: 0.91)
        case .div12:
            return Color(red: 0.17, green: 0.63, blue: 0.53)
        case .educational:
            return Color(red: 0.93, green: 0.61, blue: 0.20)
        case .div3:
            return Color(red: 0.54, green: 0.39, blue: 0.89)
        case .global:
            return AppTheme.accent
        }
    }
}
