import Foundation

@MainActor
final class AuthViewModel: ObservableObject {
    enum Mode: String, CaseIterable, Identifiable {
        case login = "Login"
        case signup = "Create Account"

        var id: String { rawValue }
    }

    @Published var mode: Mode = .login
    @Published var loginEmail: String = ""
    @Published var loginPassword: String = ""
    @Published var signUpInput = SignUpInput()
    @Published var errorMessage: String?

    func submit(using sessionStore: SessionStore) async {
        errorMessage = nil

        do {
            switch mode {
            case .login:
                try await sessionStore.signIn(email: loginEmail, password: loginPassword)
            case .signup:
                try await sessionStore.signUp(using: signUpInput)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
