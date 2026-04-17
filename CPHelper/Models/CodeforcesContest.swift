import Foundation

struct CodeforcesContest: Codable, Identifiable, Hashable {
    let id: Int
    let name: String
    let phase: String
    let type: String?
    let durationSeconds: Int
    let startTime: Date
    let relativeTimeSeconds: Int?

    var contestURL: URL {
        URL(string: "https://codeforces.com/contest/\(id)")!
    }

    var startsIn: TimeInterval {
        startTime.timeIntervalSinceNow
    }

    var hasStarted: Bool {
        startsIn <= 0
    }

    var countdownLabel: String {
        let remainingSeconds = max(Int(startsIn), 0)
        let days = remainingSeconds / 86_400
        let hours = (remainingSeconds % 86_400) / 3_600
        let minutes = (remainingSeconds % 3_600) / 60

        if days > 0 {
            return "\(days)d \(hours)h left"
        }

        if hours > 0 {
            return "\(hours)h \(minutes)m left"
        }

        return "\(minutes)m left"
    }

    var durationLabel: String {
        let hours = durationSeconds / 3_600
        let minutes = (durationSeconds % 3_600) / 60

        if minutes == 0 {
            return "\(hours)h"
        }

        return "\(hours)h \(minutes)m"
    }

    var dateBadge: String {
        ContestFormatting.dayLabel.string(from: startTime)
    }

    var startDateLabel: String {
        ContestFormatting.dateAndTime.string(from: startTime)
    }

    var shortStartTimeLabel: String {
        ContestFormatting.timeOnly.string(from: startTime)
    }

    var roundBadge: String {
        let lowered = name.lowercased()

        if lowered.contains("educational") {
            return "Educational"
        }

        if lowered.contains("global") {
            return "Global"
        }

        if lowered.contains("div. 1 + div. 2") || lowered.contains("div. 1+2") {
            return "Div 1 + 2"
        }

        if lowered.contains("div. 1") {
            return "Div 1"
        }

        if lowered.contains("div. 2") {
            return "Div 2"
        }

        if lowered.contains("div. 3") || lowered.contains("div. 4") {
            return "Div 3 / 4"
        }

        return "Codeforces"
    }
}

struct ContestRegistrationRecord: Codable, Identifiable, Equatable, Hashable {
    let contestId: Int
    let handle: String
    var isRegistered: Bool
    var updatedAt: Date

    init(
        contestId: Int,
        handle: String,
        isRegistered: Bool,
        updatedAt: Date = .now
    ) {
        self.contestId = contestId
        self.handle = handle.trimmingCharacters(in: .whitespacesAndNewlines)
        self.isRegistered = isRegistered
        self.updatedAt = updatedAt
    }

    var id: String {
        "\(contestId)::\(handle.lowercased())"
    }
}

enum ContestReminderSeverity: String, Hashable {
    case neutral
    case warning
    case danger
}

enum ContestReminderKind: String, Hashable, Identifiable {
    case dayBefore
    case threeHours
    case finalHour

    var id: String { rawValue }

    var titlePrefix: String {
        switch self {
        case .dayBefore:
            return "24h Reminder"
        case .threeHours:
            return "3h Registration Check"
        case .finalHour:
            return "Final Reminder"
        }
    }

    var leadTime: TimeInterval {
        switch self {
        case .dayBefore:
            return 24 * 60 * 60
        case .threeHours:
            return 3 * 60 * 60
        case .finalHour:
            return 60 * 60
        }
    }
}

struct ContestReminderItem: Identifiable, Hashable {
    let contest: CodeforcesContest
    let kind: ContestReminderKind
    let scheduledDate: Date
    let title: String
    let message: String
    let severity: ContestReminderSeverity

    var id: String {
        "\(contest.id)::\(kind.rawValue)"
    }

    var timeLabel: String {
        ContestFormatting.dateAndTime.string(from: scheduledDate)
    }

    func isDue(referenceDate: Date = .now) -> Bool {
        scheduledDate <= referenceDate
    }
}

private enum ContestFormatting {
    static let dayLabel: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, d MMM"
        return formatter
    }()

    static let dateAndTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    static let timeOnly: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }()
}
