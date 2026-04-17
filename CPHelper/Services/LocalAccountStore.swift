import CryptoKit
import Foundation

enum AccountStoreError: LocalizedError {
    case invalidFullName
    case invalidEmail
    case invalidMobileNumber
    case weakPassword
    case passwordMismatch
    case duplicateEmail
    case invalidCredentials
    case accountNotFound
    case duplicateHandle

    var errorDescription: String? {
        switch self {
        case .invalidFullName:
            return "Please enter your full name."
        case .invalidEmail:
            return "Please enter a valid email address."
        case .invalidMobileNumber:
            return "Please enter a valid mobile number."
        case .weakPassword:
            return "Password must be at least 8 characters long."
        case .passwordMismatch:
            return "Password and confirmation do not match."
        case .duplicateEmail:
            return "An account with this email already exists."
        case .invalidCredentials:
            return "Incorrect email or password."
        case .accountNotFound:
            return "We could not find that account."
        case .duplicateHandle:
            return "That handle is already added to your profile."
        }
    }
}

actor LocalAccountStore {
    static let shared = LocalAccountStore()

    private struct StoredAccount: Codable {
        var email: String
        var passwordHash: String
        var passwordSalt: String
        var profile: UserProfile
    }

    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let sessionKey = "cphelper.activeUserEmail"
    private let fileManager = FileManager.default

    init() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    func restoreSession() throws -> UserProfile? {
        guard let activeEmail = UserDefaults.standard.string(forKey: sessionKey)?.lowercased() else {
            return nil
        }

        let account = try loadAccounts().first { $0.email == activeEmail }
        return account?.profile
    }

    func signUp(using input: SignUpInput) throws -> UserProfile {
        let normalizedEmail = normalizeEmail(input.email)
        let fullName = input.fullName.trimmingCharacters(in: .whitespacesAndNewlines)
        let mobileNumber = input.mobileNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        let universityName = input.universityName.trimmingCharacters(in: .whitespacesAndNewlines)
        let optionalHandle = input.codeforcesHandle.trimmingCharacters(in: .whitespacesAndNewlines)

        guard fullName.count >= 2 else { throw AccountStoreError.invalidFullName }
        guard isValidEmail(normalizedEmail) else { throw AccountStoreError.invalidEmail }
        guard isValidPhone(mobileNumber) else { throw AccountStoreError.invalidMobileNumber }
        guard input.password.count >= 8 else { throw AccountStoreError.weakPassword }
        guard input.password == input.confirmPassword else { throw AccountStoreError.passwordMismatch }

        var accounts = try loadAccounts()

        guard !accounts.contains(where: { $0.email == normalizedEmail }) else {
            throw AccountStoreError.duplicateEmail
        }

        let handles = optionalHandle.isEmpty
            ? []
            : [TrackedHandle(handle: optionalHandle, isPrimary: true)]

        let profile = UserProfile(
            email: normalizedEmail,
            fullName: fullName,
            mobileNumber: mobileNumber,
            universityName: universityName,
            handles: handles
        )

        let salt = UUID().uuidString.replacingOccurrences(of: "-", with: "")
        let account = StoredAccount(
            email: normalizedEmail,
            passwordHash: hashedPassword(input.password, salt: salt),
            passwordSalt: salt,
            profile: profile
        )

        accounts.append(account)
        try saveAccounts(accounts)
        UserDefaults.standard.set(normalizedEmail, forKey: sessionKey)
        return profile
    }

    func signIn(email: String, password: String) throws -> UserProfile {
        let normalizedEmail = normalizeEmail(email)
        let accounts = try loadAccounts()

        guard let account = accounts.first(where: { $0.email == normalizedEmail }) else {
            throw AccountStoreError.invalidCredentials
        }

        let candidateHash = hashedPassword(password, salt: account.passwordSalt)

        guard candidateHash == account.passwordHash else {
            throw AccountStoreError.invalidCredentials
        }

        UserDefaults.standard.set(normalizedEmail, forKey: sessionKey)
        return account.profile
    }

    func signOut() {
        UserDefaults.standard.removeObject(forKey: sessionKey)
    }

    func updateProfile(_ profile: UserProfile) throws -> UserProfile {
        var accounts = try loadAccounts()
        let normalizedEmail = normalizeEmail(profile.email)
        let updatedProfile = UserProfile(
            id: profile.id,
            email: normalizedEmail,
            fullName: profile.fullName.trimmingCharacters(in: .whitespacesAndNewlines),
            mobileNumber: profile.mobileNumber.trimmingCharacters(in: .whitespacesAndNewlines),
            universityName: profile.universityName.trimmingCharacters(in: .whitespacesAndNewlines),
            handles: profile.handles,
            memberSince: profile.memberSince,
            updatedAt: .now
        )

        guard updatedProfile.fullName.count >= 2 else { throw AccountStoreError.invalidFullName }
        guard isValidEmail(normalizedEmail) else { throw AccountStoreError.invalidEmail }
        guard isValidPhone(updatedProfile.mobileNumber) else { throw AccountStoreError.invalidMobileNumber }

        guard let index = accounts.firstIndex(where: { $0.email == normalizedEmail }) else {
            throw AccountStoreError.accountNotFound
        }

        accounts[index].profile = updatedProfile
        try saveAccounts(accounts)
        UserDefaults.standard.set(normalizedEmail, forKey: sessionKey)
        return updatedProfile
    }

    private func loadAccounts() throws -> [StoredAccount] {
        let url = try accountsFileURL()

        guard fileManager.fileExists(atPath: url.path) else {
            return []
        }

        let data = try Data(contentsOf: url)
        return try decoder.decode([StoredAccount].self, from: data)
    }

    private func saveAccounts(_ accounts: [StoredAccount]) throws {
        let url = try accountsFileURL()
        let data = try encoder.encode(accounts)
        try data.write(to: url, options: .atomic)
    }

    private func accountsFileURL() throws -> URL {
        let baseDirectory = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )

        let folderURL = baseDirectory.appendingPathComponent("CPHelper", isDirectory: true)
        if !fileManager.fileExists(atPath: folderURL.path) {
            try fileManager.createDirectory(at: folderURL, withIntermediateDirectories: true, attributes: nil)
        }

        return folderURL.appendingPathComponent("accounts.json")
    }

    private func normalizeEmail(_ email: String) -> String {
        email
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }

    private func isValidEmail(_ email: String) -> Bool {
        let pattern = #"^[A-Z0-9._%+\-]+@[A-Z0-9.\-]+\.[A-Z]{2,}$"#
        return email.range(
            of: pattern,
            options: [.regularExpression, .caseInsensitive]
        ) != nil
    }

    private func isValidPhone(_ number: String) -> Bool {
        let digits = number.filter(\.isNumber)
        return (8...15).contains(digits.count)
    }

    private func hashedPassword(_ password: String, salt: String) -> String {
        let data = Data((salt + password).utf8)
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
