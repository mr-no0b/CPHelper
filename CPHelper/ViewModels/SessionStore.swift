import Combine
import Foundation

@MainActor
final class SessionStore: ObservableObject {
    @Published private(set) var currentUser: UserProfile?
    @Published private(set) var isBootstrapping = true
    @Published private(set) var isWorking = false

    private let providedAccountStore: FirebaseAccountStore?

    private var accountStore: FirebaseAccountStore {
        providedAccountStore ?? .shared
    }

    init(accountStore: FirebaseAccountStore? = nil) {
        self.providedAccountStore = accountStore
    }

    init(previewUser: UserProfile?) {
        self.providedAccountStore = nil
        self.currentUser = previewUser
        self.isBootstrapping = false
        self.isWorking = false
    }

    var isAuthenticated: Bool {
        currentUser != nil
    }

    func restoreSessionIfNeeded() async {
        guard isBootstrapping else { return }
        await restoreSession()
    }

    func restoreSession() async {
        do {
            currentUser = try await accountStore.restoreSession()
        } catch {
            currentUser = nil
        }

        isBootstrapping = false
    }

    func signIn(email: String, password: String) async throws {
        isWorking = true
        defer { isWorking = false }

        currentUser = try await accountStore.signIn(email: email, password: password)
    }

    func signUp(using input: SignUpInput) async throws {
        isWorking = true
        defer { isWorking = false }

        currentUser = try await accountStore.signUp(using: input)
    }

    func updateProfile(_ profile: UserProfile) async throws {
        isWorking = true
        defer { isWorking = false }

        currentUser = try await accountStore.updateProfile(profile)
    }

    func setPrimaryHandle(_ handle: String?) async throws {
        guard let currentUser else { return }

        isWorking = true
        defer { isWorking = false }

        self.currentUser = try await accountStore.setPrimaryHandle(handle, userID: currentUser.id)
    }

    func addFriend(handle: String, nickname: String) async throws {
        guard let currentUser else { return }

        isWorking = true
        defer { isWorking = false }

        self.currentUser = try await accountStore.addFriend(
            handle: handle,
            nickname: nickname,
            userID: currentUser.id
        )
    }

    func removeFriend(friendID: UUID) async throws {
        guard let currentUser else { return }

        isWorking = true
        defer { isWorking = false }

        self.currentUser = try await accountStore.removeFriend(friendID: friendID, userID: currentUser.id)
    }

    func addTodoProblem(_ problem: CodeforcesProblem, for handle: String) async throws {
        guard let currentUser else { return }

        isWorking = true
        defer { isWorking = false }

        self.currentUser = try await accountStore.addTodoProblem(
            problem,
            for: handle,
            userID: currentUser.id
        )
    }

    func removeTodoProblem(todoID: String) async throws {
        guard let currentUser else { return }

        isWorking = true
        defer { isWorking = false }

        self.currentUser = try await accountStore.removeTodoProblem(
            todoID: todoID,
            userID: currentUser.id
        )
    }

    func setContestRegistration(
        contestId: Int,
        handle: String,
        isRegistered: Bool
    ) async throws {
        guard let currentUser else { return }

        isWorking = true
        defer { isWorking = false }

        self.currentUser = try await accountStore.setContestRegistration(
            contestId: contestId,
            handle: handle,
            isRegistered: isRegistered,
            userID: currentUser.id
        )
    }

    func addTodoProblem(from problemLink: String) async throws {
        guard let currentUser else { return }
        guard let primaryHandle = currentUser.primaryHandle, !primaryHandle.isEmpty else {
            throw AccountStoreError.missingPrimaryHandle
        }

        guard let problem = try await CodeforcesProblemCatalogService.shared.problem(for: problemLink) else {
            throw AccountStoreError.invalidProblemLink
        }

        try await addTodoProblem(problem, for: primaryHandle)
    }

    func signOut() async {
        isWorking = true
        await accountStore.signOut()
        currentUser = nil
        isWorking = false
    }
}
