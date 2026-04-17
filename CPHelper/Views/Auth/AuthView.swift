import SwiftUI

struct AuthView: View {
    @EnvironmentObject private var sessionStore: SessionStore
    @StateObject private var viewModel = AuthViewModel()

    var body: some View {
        ZStack {
            AppBackdrop()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    heroSection
                    formSection
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 28)
            }
        }
    }

    private var heroSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Compete smarter.\nTrack every breakthrough.")
                .font(.system(size: 38, weight: .bold, design: .rounded))
                .foregroundStyle(AppTheme.text)

            Text("A cleaner competitive programming workspace with account access, multi-handle tracking, and modern Codeforces analysis.")
                .font(.system(.body, design: .rounded))
                .foregroundStyle(AppTheme.mutedText)

            HStack(spacing: 12) {
                MetricChip(title: "Auth", value: "Secure local")
                MetricChip(title: "Profiles", value: "Multi handle")
                MetricChip(title: "Analysis", value: "Live CF data")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 10)
    }

    private var formSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            Picker("Mode", selection: $viewModel.mode) {
                ForEach(AuthViewModel.Mode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            if viewModel.mode == .login {
                loginFields
            } else {
                signUpFields
            }

            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(Color(red: 0.80, green: 0.23, blue: 0.24))
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color.red.opacity(0.08))
                    )
            }

            Button {
                Task {
                    await viewModel.submit(using: sessionStore)
                }
            } label: {
                HStack {
                    if sessionStore.isWorking {
                        ProgressView()
                            .tint(.white)
                    }

                    Text(viewModel.mode == .login ? "Login" : "Create Account")
                }
            }
            .buttonStyle(AppPrimaryButtonStyle())
            .disabled(sessionStore.isWorking)

            Text(viewModel.mode == .login ? "Welcome back. Your profile, tracked handles, and analysis hub are waiting." : "Create your profile with a strong base and start tracking handles right away.")
                .font(.system(.footnote, design: .rounded))
                .foregroundStyle(AppTheme.mutedText)
        }
        .appCard()
    }

    private var loginFields: some View {
        VStack(alignment: .leading, spacing: 14) {
            fieldLabel("Email")
            TextField("name@example.com", text: $viewModel.loginEmail)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .appInputField()

            fieldLabel("Password")
            SecureField("At least 8 characters", text: $viewModel.loginPassword)
                .textInputAutocapitalization(.never)
                .appInputField()
        }
    }

    private var signUpFields: some View {
        VStack(alignment: .leading, spacing: 14) {
            fieldLabel("Full Name")
            TextField("Your name", text: $viewModel.signUpInput.fullName)
                .appInputField()

            fieldLabel("Email")
            TextField("name@example.com", text: $viewModel.signUpInput.email)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .appInputField()

            fieldLabel("Mobile Number")
            TextField("+8801XXXXXXXXX", text: $viewModel.signUpInput.mobileNumber)
                .keyboardType(.phonePad)
                .appInputField()

            fieldLabel("Password")
            SecureField("At least 8 characters", text: $viewModel.signUpInput.password)
                .textInputAutocapitalization(.never)
                .appInputField()

            fieldLabel("Confirm Password")
            SecureField("Re-enter password", text: $viewModel.signUpInput.confirmPassword)
                .textInputAutocapitalization(.never)
                .appInputField()

            fieldLabel("University Name (Optional)")
            TextField("University", text: $viewModel.signUpInput.universityName)
                .appInputField()

            fieldLabel("Codeforces Handle (Optional)")
            TextField("tourist", text: $viewModel.signUpInput.codeforcesHandle)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .appInputField()
        }
    }

    private func fieldLabel(_ title: String) -> some View {
        Text(title)
            .font(.system(.subheadline, design: .rounded).weight(.semibold))
            .foregroundStyle(AppTheme.text)
    }
}

#Preview {
    AuthView()
        .environmentObject(SessionStore())
}
