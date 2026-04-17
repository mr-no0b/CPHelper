import Foundation

struct UserProfile: Codable, Identifiable, Equatable {
    var id: UUID
    var email: String
    var fullName: String
    var mobileNumber: String
    var universityName: String
    var handles: [TrackedHandle]
    var todoProblems: [TodoProblem]
    var memberSince: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        email: String,
        fullName: String,
        mobileNumber: String,
        universityName: String = "",
        handles: [TrackedHandle] = [],
        todoProblems: [TodoProblem] = [],
        memberSince: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.email = email
        self.fullName = fullName
        self.mobileNumber = mobileNumber
        self.universityName = universityName
        self.handles = handles.normalizedHandles()
        self.todoProblems = todoProblems.sorted { $0.addedAt > $1.addedAt }
        self.memberSince = memberSince
        self.updatedAt = updatedAt
    }

    var primaryHandle: String? {
        handles.first(where: \.isPrimary)?.handle ?? handles.first?.handle
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

    private enum CodingKeys: String, CodingKey {
        case id
        case email
        case fullName
        case mobileNumber
        case universityName
        case handles
        case todoProblems
        case memberSince
        case updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        email = try container.decode(String.self, forKey: .email)
        fullName = try container.decode(String.self, forKey: .fullName)
        mobileNumber = try container.decode(String.self, forKey: .mobileNumber)
        universityName = try container.decodeIfPresent(String.self, forKey: .universityName) ?? ""
        handles = (try container.decodeIfPresent([TrackedHandle].self, forKey: .handles) ?? []).normalizedHandles()
        todoProblems = (try container.decodeIfPresent([TodoProblem].self, forKey: .todoProblems) ?? [])
            .sorted { $0.addedAt > $1.addedAt }
        memberSince = try container.decodeIfPresent(Date.self, forKey: .memberSince) ?? .now
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? .now
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(email, forKey: .email)
        try container.encode(fullName, forKey: .fullName)
        try container.encode(mobileNumber, forKey: .mobileNumber)
        try container.encode(universityName, forKey: .universityName)
        try container.encode(handles.normalizedHandles(), forKey: .handles)
        try container.encode(todoProblems.sorted { $0.addedAt > $1.addedAt }, forKey: .todoProblems)
        try container.encode(memberSince, forKey: .memberSince)
        try container.encode(updatedAt, forKey: .updatedAt)
    }
}

struct TrackedHandle: Codable, Identifiable, Equatable, Hashable {
    var id: UUID
    var handle: String
    var label: String
    var isPrimary: Bool
    var addedAt: Date

    init(
        id: UUID = UUID(),
        handle: String,
        label: String = "",
        isPrimary: Bool = false,
        addedAt: Date = .now
    ) {
        self.id = id
        self.handle = handle.trimmingCharacters(in: .whitespacesAndNewlines)
        self.label = label.trimmingCharacters(in: .whitespacesAndNewlines)
        self.isPrimary = isPrimary
        self.addedAt = addedAt
    }
}

struct SignUpInput {
    var fullName: String = ""
    var email: String = ""
    var mobileNumber: String = ""
    var password: String = ""
    var confirmPassword: String = ""
    var universityName: String = ""
    var codeforcesHandle: String = ""
}

extension Array where Element == TrackedHandle {
    func normalizedHandles() -> [TrackedHandle] {
        var seen: Set<String> = []
        let uniqueHandles = self.filter { handle in
            let normalized = handle.handle.lowercased()
            guard !normalized.isEmpty, !seen.contains(normalized) else { return false }
            seen.insert(normalized)
            return true
        }

        guard !uniqueHandles.isEmpty else { return [] }

        if uniqueHandles.contains(where: \.isPrimary) {
            var didAssignPrimary = false

            return uniqueHandles.map { handle in
                var updatedHandle = handle
                if handle.isPrimary, !didAssignPrimary {
                    didAssignPrimary = true
                    updatedHandle.isPrimary = true
                } else {
                    updatedHandle.isPrimary = false
                }
                return updatedHandle
            }
        }

        return uniqueHandles.enumerated().map { index, handle in
            var updatedHandle = handle
            updatedHandle.isPrimary = index == 0
            return updatedHandle
        }
    }
}
