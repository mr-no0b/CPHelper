import Foundation

@MainActor
final class SessionStore: ObservableObject {
    @Published private(set) var currentUser: UserProfile?
    @Published private(set) var isBootstrapping = true
    @Published private(set) var isWorking = false

    private let accountStore: LocalAccountStore

    init(accountStore: LocalAccountStore = .shared) {
        self.accountStore = accountStore

        Task {
            await restoreSession()
        }
    }

    init(previewUser: UserProfile?) {
        self.accountStore = .shared
        self.currentUser = previewUser
        self.isBootstrapping = false
        self.isWorking = false
    }

    var isAuthenticated: Bool {
        currentUser != nil
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

    func signOut() async {
        isWorking = true
        await accountStore.signOut()
        currentUser = nil
        isWorking = false
    }
}
