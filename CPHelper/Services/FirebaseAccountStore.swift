import Foundation
import FirebaseAuth
import FirebaseCore
import FirebaseFirestore
import OSLog

enum AccountStoreError: LocalizedError {
    case invalidFullName
    case invalidEmail
    case invalidMobileNumber
    case weakPassword
    case passwordMismatch
    case duplicateFriend
    case invalidCredentials
    case emailAlreadyInUse
    case signInProviderDisabled
    case firebaseConfigurationMissing
    case invalidFirebaseAPIKey
    case firebaseServerError(String)
    case networkUnavailable
    case tooManyRequests
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
        case .emailAlreadyInUse:
            return "An account already exists for this email address."
        case .signInProviderDisabled:
            return "Email/password sign-in is disabled for this Firebase project. Enable it in Firebase Authentication."
        case .firebaseConfigurationMissing:
            return "Firebase Authentication is not configured for this project. In Firebase Console, open Authentication and enable Email/Password sign-in."
        case .invalidFirebaseAPIKey:
            return "Firebase rejected this app's API key. Check that GoogleService-Info.plist belongs to this Firebase project and bundle ID."
        case .firebaseServerError(let message):
            return "Firebase Auth rejected the request: \(message)"
        case .networkUnavailable:
            return "Could not reach Firebase. Check your internet connection and try again."
        case .tooManyRequests:
            return "Firebase temporarily blocked this request because of too many attempts. Try again later."
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
    private let logger = Logger(subsystem: "lalon.CPHelper", category: "FirebaseAccountStore")
    private let collectionName = "users"

    init(
        auth: Auth? = nil,
        database: Firestore? = nil,
        cacheStore: ProfileCacheStore = ProfileCacheStore()
    ) {
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

            try await persistProfile(profile)
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

        try await persistProfile(updatedProfile)
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
        do {
            let snapshot = try await reference.getDocument()

            if let data = snapshot.data() {
                let profile = try decodeProfile(from: data)
                try? await cacheStore.save(profile)
                return profile
            }

            let profile = fallbackProfile(for: firebaseUser)
            try await persistProfile(profile)
            return profile
        } catch {
            if let cached = try? await cacheStore.load(userID: firebaseUser.uid) {
                logger.warning("Using cached profile after remote profile load failed: \(error.localizedDescription, privacy: .public)")
                return cached
            }

            logger.warning("Using fallback Firebase Auth profile after remote profile load failed: \(error.localizedDescription, privacy: .public)")
            return fallbackProfile(for: firebaseUser)
        }
    }

    private func saveProfile(_ profile: UserProfile) async throws {
        try await userDocument(userID: profile.id).setData(try encodeProfile(profile))
    }

    private func mutateProfile(
        userID: String,
        mutation: (inout UserProfile) throws -> Void
    ) async throws -> UserProfile {
        let reference = userDocument(userID: userID)
        let profile = try await loadProfileForMutation(reference: reference, userID: userID)

        var updatedProfile = profile
        try mutation(&updatedProfile)
        updatedProfile.updatedAt = .now

        try await persistProfile(updatedProfile)
        return updatedProfile
    }

    private func loadProfileForMutation(reference: DocumentReference, userID: String) async throws -> UserProfile {
        do {
            let snapshot = try await reference.getDocument()

            if let data = snapshot.data() {
                return try decodeProfile(from: data)
            }
        } catch {
            logger.warning("Remote profile load failed before mutation: \(error.localizedDescription, privacy: .public)")
        }

        if let cached = try? await cacheStore.load(userID: userID) {
            return cached
        }

        if let authUser = auth.currentUser, authUser.uid == userID {
            return fallbackProfile(for: authUser)
        }

        throw AccountStoreError.accountNotFound
    }

    private func fallbackProfile(for firebaseUser: FirebaseAuth.User) -> UserProfile {
        UserProfile(
            id: firebaseUser.uid,
            email: firebaseUser.email ?? "",
            fullName: firebaseUser.displayName ?? "",
            mobileNumber: ""
        )
    }

    private func persistProfile(_ profile: UserProfile) async throws {
        var didSaveRemote = false
        var remoteError: Error?

        do {
            try await saveProfile(profile)
            didSaveRemote = true
        } catch {
            remoteError = error
            logger.warning("Remote profile sync failed; continuing with local cache if possible: \(error.localizedDescription, privacy: .public)")
        }

        do {
            try await cacheStore.save(profile)
        } catch {
            guard didSaveRemote else {
                throw remoteError ?? error
            }

            logger.warning("Local profile cache save failed after remote sync succeeded: \(error.localizedDescription, privacy: .public)")
        }
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
        logger.error("Firebase Auth error details: \(self.describe(error), privacy: .public)")

        if let serverMessage = firebaseServerMessage(from: error) {
            let normalized = serverMessage.uppercased()

            if normalized.contains("CONFIGURATION_NOT_FOUND") {
                return AccountStoreError.firebaseConfigurationMissing
            }

            if normalized.contains("OPERATION_NOT_ALLOWED") {
                return AccountStoreError.signInProviderDisabled
            }

            if normalized.contains("API_KEY_INVALID") || normalized.contains("INVALID_API_KEY") {
                return AccountStoreError.invalidFirebaseAPIKey
            }

            return AccountStoreError.firebaseServerError(serverMessage)
        }

        let code = AuthErrorCode(rawValue: error.code)

        switch code {
        case .some(.wrongPassword), .some(.invalidCredential), .some(.invalidEmail), .some(.userNotFound):
            return AccountStoreError.invalidCredentials
        case .some(.emailAlreadyInUse):
            return AccountStoreError.emailAlreadyInUse
        case .some(.operationNotAllowed):
            return AccountStoreError.signInProviderDisabled
        case .some(.networkError):
            return AccountStoreError.networkUnavailable
        case .some(.tooManyRequests):
            return AccountStoreError.tooManyRequests
        default:
            return error
        }
    }

    private func firebaseServerMessage(from error: NSError) -> String? {
        let responseKey = "FIRAuthErrorUserInfoDeserializedResponseKey"

        if let response = error.userInfo[responseKey],
           let message = message(fromFirebaseResponse: response) {
            return message
        }

        if let data = error.userInfo["FIRAuthErrorUserInfoDataKey"] as? Data,
           let object = try? JSONSerialization.jsonObject(with: data),
           let message = message(fromFirebaseResponse: object) {
            return message
        }

        if let underlying = error.userInfo[NSUnderlyingErrorKey] as? NSError {
            return firebaseServerMessage(from: underlying)
        }

        return nil
    }

    private func message(fromFirebaseResponse response: Any) -> String? {
        guard let dictionary = response as? [String: Any] else {
            return String(describing: response)
        }

        if let error = dictionary["error"] as? [String: Any] {
            if let message = error["message"] as? String, !message.isEmpty {
                return message
            }

            if let status = error["status"] as? String, !status.isEmpty {
                return status
            }
        }

        if let message = dictionary["message"] as? String, !message.isEmpty {
            return message
        }

        if let error = dictionary["error"] as? String, !error.isEmpty {
            return error
        }

        return nil
    }

    private func describe(_ error: NSError) -> String {
        var parts = [
            "domain=\(error.domain)",
            "code=\(error.code)",
            "description=\(error.localizedDescription)"
        ]

        if let serverMessage = firebaseServerMessage(from: error) {
            parts.append("serverMessage=\(serverMessage)")
        }

        if let name = error.userInfo[AuthErrorUserInfoNameKey] as? String {
            parts.append("name=\(name)")
        }

        if let failureReason = error.userInfo[NSLocalizedFailureReasonErrorKey] as? String {
            parts.append("reason=\(failureReason)")
        }

        if let underlying = error.userInfo[NSUnderlyingErrorKey] as? NSError {
            parts.append("underlying={\(describe(underlying))}")
        }

        return parts.joined(separator: ", ")
    }
}
