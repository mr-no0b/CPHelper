import Foundation

struct UserProfile: Codable, Identifiable, Equatable {
    var id: String
    var email: String
    var fullName: String
    var mobileNumber: String
    var universityName: String
    var profileImageURLString: String
    var primaryHandle: String?
    var friends: [FriendProfile]
    var contestRegistrations: [ContestRegistrationRecord]
    var todoProblems: [TodoProblem]
    var memberSince: Date
    var updatedAt: Date

    init(
        id: String = UUID().uuidString,
        email: String,
        fullName: String,
        mobileNumber: String,
        universityName: String = "",
        profileImageURLString: String = "",
        primaryHandle: String? = nil,
        friends: [FriendProfile] = [],
        contestRegistrations: [ContestRegistrationRecord] = [],
        todoProblems: [TodoProblem] = [],
        memberSince: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.email = email
        self.fullName = fullName.trimmingCharacters(in: .whitespacesAndNewlines)
        self.mobileNumber = mobileNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        self.universityName = universityName.trimmingCharacters(in: .whitespacesAndNewlines)
        self.profileImageURLString = profileImageURLString.trimmingCharacters(in: .whitespacesAndNewlines)

        let normalizedHandle = primaryHandle?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.primaryHandle = normalizedHandle?.isEmpty == true ? nil : normalizedHandle

        self.friends = friends.normalizedFriends()
        self.contestRegistrations = contestRegistrations.normalizedContestRegistrations()
        self.todoProblems = todoProblems.sorted { $0.addedAt > $1.addedAt }
        self.memberSince = memberSince
        self.updatedAt = updatedAt
    }

    var initials: String {
        let parts = fullName
            .split(separator: " ")
            .prefix(2)
            .map { String($0.prefix(1)).uppercased() }

        if parts.isEmpty {
            return String(email.prefix(1)).uppercased()
        }

        return parts.joined()
    }

    var profileImageURL: URL? {
        guard !profileImageURLString.isEmpty else { return nil }
        return URL(string: profileImageURLString)
    }

    func registrationRecord(contestId: Int) -> ContestRegistrationRecord? {
        guard let primaryHandle else { return nil }

        return contestRegistrations.first {
            $0.contestId == contestId
                && $0.handle.caseInsensitiveCompare(primaryHandle) == .orderedSame
        }
    }

    func isRegistered(for contestId: Int) -> Bool {
        registrationRecord(contestId: contestId)?.isRegistered ?? false
    }
}

struct FriendProfile: Codable, Identifiable, Equatable, Hashable {
    var id: UUID
    var handle: String
    var nickname: String
    var addedAt: Date

    init(
        id: UUID = UUID(),
        handle: String,
        nickname: String = "",
        addedAt: Date = .now
    ) {
        self.id = id
        self.handle = handle.trimmingCharacters(in: .whitespacesAndNewlines)
        self.nickname = nickname.trimmingCharacters(in: .whitespacesAndNewlines)
        self.addedAt = addedAt
    }

    var displayName: String {
        nickname.isEmpty ? handle : nickname
    }
}

struct SignUpInput {
    var fullName: String = ""
    var email: String = ""
    var mobileNumber: String = ""
    var password: String = ""
    var confirmPassword: String = ""
    var universityName: String = ""
    var primaryHandle: String = ""
}

extension Array where Element == FriendProfile {
    func normalizedFriends() -> [FriendProfile] {
        var seen: Set<String> = []

        return self.filter { friend in
            let normalized = friend.handle.lowercased()
            guard !normalized.isEmpty, !seen.contains(normalized) else { return false }
            seen.insert(normalized)
            return true
        }
        .sorted { $0.addedAt < $1.addedAt }
    }
}

extension Array where Element == ContestRegistrationRecord {
    func normalizedContestRegistrations() -> [ContestRegistrationRecord] {
        var latestByID: [String: ContestRegistrationRecord] = [:]

        for registration in self {
            let key = registration.id
            if let existing = latestByID[key] {
                if registration.updatedAt > existing.updatedAt {
                    latestByID[key] = registration
                }
            } else {
                latestByID[key] = registration
            }
        }

        return latestByID.values.sorted { $0.updatedAt > $1.updatedAt }
    }
}
