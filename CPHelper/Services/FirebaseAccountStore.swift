import Foundation
import FirebaseAuth
import FirebaseCore
import FirebaseFirestore

enum AccountStoreError: LocalizedError {
    case invalidFullName
    case invalidEmail
    case invalidMobileNumber
    case weakPassword
    case passwordMismatch
    case duplicateFriend
    case invalidCredentials
    case accountNotFound
    case missingPrimaryHandle
    case invalidProblemLink

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
        case .duplicateFriend:
            return "That friend handle is already added."
        case .invalidCredentials:
            return "Incorrect email or password."
        case .accountNotFound:
            return "We could not find that account."
        case .missingPrimaryHandle:
            return "Add your primary Codeforces handle first."
        case .invalidProblemLink:
            return "Paste a valid Codeforces problem link."
        }
    }
}

actor FirebaseAccountStore {
    static let shared = FirebaseAccountStore()

    private let auth: Auth
    private let database: Firestore
    private let cacheStore: ProfileCacheStore
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let collectionName = "users"

    init(
        auth: Auth? = nil,
        database: Firestore? = nil,
        cacheStore: ProfileCacheStore = ProfileCacheStore()
    ) {
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }

        self.auth = auth ?? Auth.auth()
        self.database = database ?? Firestore.firestore()
        self.cacheStore = cacheStore

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    func restoreSession() async throws -> UserProfile? {
        guard let firebaseUser = auth.currentUser else {
            return nil
        }

        do {
            let profile = try await loadOrCreateProfile(for: firebaseUser)
            try? await cacheStore.save(profile)
            return profile
        } catch {
            if let cached = try? await cacheStore.load(userID: firebaseUser.uid) {
                return cached
            }
            throw error
        }
    }

    func signIn(email: String, password: String) async throws -> UserProfile {
        let normalizedEmail = normalizeEmail(email)
        guard isValidEmail(normalizedEmail) else { throw AccountStoreError.invalidEmail }

        do {
            let result = try await auth.signIn(withEmail: normalizedEmail, password: password)
            let profile = try await loadOrCreateProfile(for: result.user)
            try? await cacheStore.save(profile)
            return profile
        } catch let error as NSError {
            throw mapAuthError(error)
        }
    }

    func signUp(using input: SignUpInput) async throws -> UserProfile {
        let normalizedEmail = normalizeEmail(input.email)
        let fullName = input.fullName.trimmingCharacters(in: .whitespacesAndNewlines)
        let mobileNumber = input.mobileNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        let universityName = input.universityName.trimmingCharacters(in: .whitespacesAndNewlines)
        let primaryHandle = input.primaryHandle.trimmingCharacters(in: .whitespacesAndNewlines)

        guard fullName.count >= 2 else { throw AccountStoreError.invalidFullName }
        guard isValidEmail(normalizedEmail) else { throw AccountStoreError.invalidEmail }
        guard isValidPhone(mobileNumber) else { throw AccountStoreError.invalidMobileNumber }
        guard input.password.count >= 8 else { throw AccountStoreError.weakPassword }
        guard input.password == input.confirmPassword else { throw AccountStoreError.passwordMismatch }

        do {
            let result = try await auth.createUser(withEmail: normalizedEmail, password: input.password)
            let profile = UserProfile(
                id: result.user.uid,
                email: normalizedEmail,
                fullName: fullName,
                mobileNumber: mobileNumber,
                universityName: universityName,
                primaryHandle: primaryHandle.isEmpty ? nil : primaryHandle
            )

            try await saveProfile(profile)
            try? await cacheStore.save(profile)
            return profile
        } catch let error as NSError {
            throw mapAuthError(error)
        }
    }

    func updateProfile(_ profile: UserProfile) async throws -> UserProfile {
        let normalizedEmail = normalizeEmail(profile.email)
        let updatedProfile = UserProfile(
            id: profile.id,
            email: normalizedEmail,
            fullName: profile.fullName,
            mobileNumber: profile.mobileNumber,
            universityName: profile.universityName,
            profileImageURLString: profile.profileImageURLString,
            primaryHandle: profile.primaryHandle,
            friends: profile.friends,
            contestRegistrations: profile.contestRegistrations,
            todoProblems: profile.todoProblems,
            memberSince: profile.memberSince,
            updatedAt: .now
        )

        guard updatedProfile.fullName.count >= 2 else { throw AccountStoreError.invalidFullName }
        guard isValidEmail(normalizedEmail) else { throw AccountStoreError.invalidEmail }
        guard isValidPhone(updatedProfile.mobileNumber) else { throw AccountStoreError.invalidMobileNumber }

        try await saveProfile(updatedProfile)
        try? await cacheStore.save(updatedProfile)
        return updatedProfile
    }

    func setPrimaryHandle(_ handle: String?, userID: String) async throws -> UserProfile {
        try await mutateProfile(userID: userID) { profile in
            let normalized = handle?.trimmingCharacters(in: .whitespacesAndNewlines)
            profile.primaryHandle = normalized?.isEmpty == true ? nil : normalized
        }
    }

    func addFriend(handle: String, nickname: String, userID: String) async throws -> UserProfile {
        try await mutateProfile(userID: userID) { profile in
            guard !profile.friends.contains(where: { $0.handle.caseInsensitiveCompare(handle) == .orderedSame }) else {
                throw AccountStoreError.duplicateFriend
            }

            profile.friends.append(
                FriendProfile(
                    handle: handle,
                    nickname: nickname
                )
            )
            profile.friends = profile.friends.normalizedFriends()
        }
    }

    func removeFriend(friendID: UUID, userID: String) async throws -> UserProfile {
        try await mutateProfile(userID: userID) { profile in
            profile.friends.removeAll { $0.id == friendID }
        }
    }

    func addTodoProblem(_ problem: CodeforcesProblem, for handle: String, userID: String) async throws -> UserProfile {
        try await mutateProfile(userID: userID) { profile in
            let todoHandle = handle.trimmingCharacters(in: .whitespacesAndNewlines)
            let fallbackHandle = profile.primaryHandle ?? todoHandle
            let todoItem = TodoProblem(handle: fallbackHandle, problem: problem)

            guard !profile.todoProblems.contains(where: { $0.id == todoItem.id }) else {
                return
            }

            profile.todoProblems.insert(todoItem, at: 0)
        }
    }

    func removeTodoProblem(todoID: String, userID: String) async throws -> UserProfile {
        try await mutateProfile(userID: userID) { profile in
            profile.todoProblems.removeAll { $0.id == todoID }
        }
    }

    func setContestRegistration(
        contestId: Int,
        handle: String,
        isRegistered: Bool,
        userID: String
    ) async throws -> UserProfile {
        try await mutateProfile(userID: userID) { profile in
            let normalizedHandle = handle.trimmingCharacters(in: .whitespacesAndNewlines)
            let updatedRecord = ContestRegistrationRecord(
                contestId: contestId,
                handle: normalizedHandle,
                isRegistered: isRegistered,
                updatedAt: .now
            )

            profile.contestRegistrations.removeAll {
                $0.contestId == contestId
                    && $0.handle.caseInsensitiveCompare(normalizedHandle) == .orderedSame
            }

            profile.contestRegistrations.insert(updatedRecord, at: 0)
            profile.contestRegistrations = profile.contestRegistrations.normalizedContestRegistrations()
        }
    }

    func signOut() async {
        let userID = auth.currentUser?.uid

        do {
            try auth.signOut()
        } catch {
            return
        }

        if let userID {
            try? await cacheStore.remove(userID: userID)
        }
    }

    private func loadOrCreateProfile(for firebaseUser: FirebaseAuth.User) async throws -> UserProfile {
        let reference = userDocument(userID: firebaseUser.uid)
        let snapshot = try await reference.getDocument()

        if let data = snapshot.data() {
            return try decodeProfile(from: data)
        }

        let profile = UserProfile(
            id: firebaseUser.uid,
            email: firebaseUser.email ?? "",
            fullName: firebaseUser.displayName ?? "",
            mobileNumber: ""
        )

        try await saveProfile(profile)
        return profile
    }

    private func saveProfile(_ profile: UserProfile) async throws {
        try await userDocument(userID: profile.id).setData(try encodeProfile(profile))
    }

    private func mutateProfile(
        userID: String,
        mutation: (inout UserProfile) throws -> Void
    ) async throws -> UserProfile {
        let reference = userDocument(userID: userID)
        let snapshot = try await reference.getDocument()

        let profile: UserProfile
        if let data = snapshot.data() {
            profile = try decodeProfile(from: data)
        } else if let authUser = auth.currentUser, authUser.uid == userID {
            profile = UserProfile(
                id: authUser.uid,
                email: authUser.email ?? "",
                fullName: authUser.displayName ?? "",
                mobileNumber: ""
            )
        } else {
            throw AccountStoreError.accountNotFound
        }

        var updatedProfile = profile
        try mutation(&updatedProfile)
        updatedProfile.updatedAt = .now

        try await saveProfile(updatedProfile)
        try? await cacheStore.save(updatedProfile)
        return updatedProfile
    }

    private func userDocument(userID: String) -> DocumentReference {
        database.collection(collectionName).document(userID)
    }

    private func encodeProfile(_ profile: UserProfile) throws -> [String: Any] {
        let data = try encoder.encode(profile)
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw AccountStoreError.accountNotFound
        }
        return object
    }

    private func decodeProfile(from object: [String: Any]) throws -> UserProfile {
        let data = try JSONSerialization.data(withJSONObject: object)
        return try decoder.decode(UserProfile.self, from: data)
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

    private func mapAuthError(_ error: NSError) -> Error {
        let code = AuthErrorCode(rawValue: error.code)

        switch code {
        case .some(.wrongPassword), .some(.invalidCredential), .some(.invalidEmail), .some(.userNotFound):
            return AccountStoreError.invalidCredentials
        case .some(.emailAlreadyInUse):
            return error
        default:
            return error
        }
    }
}
