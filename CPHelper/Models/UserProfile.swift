import Foundation

struct UserProfile: Codable, Identifiable, Equatable {
    var id: UUID
    var email: String
    var fullName: String
    var mobileNumber: String
    var universityName: String
    var handles: [TrackedHandle]
    var memberSince: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        email: String,
        fullName: String,
        mobileNumber: String,
        universityName: String = "",
        handles: [TrackedHandle] = [],
        memberSince: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.email = email
        self.fullName = fullName
        self.mobileNumber = mobileNumber
        self.universityName = universityName
        self.handles = handles.normalizedHandles()
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
