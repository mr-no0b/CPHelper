import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var sessionStore: SessionStore
    @State private var isEditing = false

    var body: some View {
        ZStack {
            AppBackdrop()

            if let user = sessionStore.currentUser {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 18) {
                        profileHeader(user: user)
                        detailsCard(user: user)
                        signOutCard
                    }
                    .padding(20)
                }
            }
        }
        .sheet(isPresented: $isEditing) {
            if let user = sessionStore.currentUser {
                ProfileEditorSheet(profile: user)
                    .environmentObject(sessionStore)
            }
        }
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func profileHeader(user: UserProfile) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 16) {
                AvatarView(
                    title: user.initials,
                    imageURL: user.profileImageURL,
                    size: 78
                )

                VStack(alignment: .leading, spacing: 6) {
                    Text(user.fullName)
                        .font(.system(.title2, design: .rounded).weight(.bold))
                        .foregroundStyle(AppTheme.text)

                    Text(user.email)
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(AppTheme.mutedText)

                    HStack(spacing: 8) {
                        if let primaryHandle = user.primaryHandle, !primaryHandle.isEmpty {
                            CodeforcesHandleView(
                                handle: primaryHandle,
                                style: .badge,
                                font: .system(.caption, design: .rounded).weight(.bold)
                            )
                        }

                        InfoBadge(title: "\(user.friends.count) friends", tint: AppTheme.accentSecondary)
                    }
                }

                Spacer()
            }

            Button("Edit Profile") {
                isEditing = true
            }
            .buttonStyle(AppPrimaryButtonStyle())
        }
        .appCard()
    }

    private func detailsCard(user: UserProfile) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionTitle(title: "Details", subtitle: "Account")

            detailRow(title: "Mobile", value: user.mobileNumber)
            detailRow(title: "University", value: user.universityName.isEmpty ? "Not added" : user.universityName)
            primaryHandleRow(user)
            detailRow(title: "Member since", value: DateFormatting.mediumDate.string(from: user.memberSince))
            detailRow(title: "Saved problems", value: "\(user.todoProblems.count)")
        }
        .appCard()
    }

    private var signOutCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionTitle(title: "Session", subtitle: "Account")

            Button(role: .destructive) {
                Task {
                    await sessionStore.signOut()
                }
            } label: {
                Text("Sign Out")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(AppPrimaryButtonStyle())
        }
        .appCard()
    }

    private func detailRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                .foregroundStyle(AppTheme.mutedText)

            Spacer()

            Text(value)
                .font(.system(.subheadline, design: .rounded).weight(.medium))
                .foregroundStyle(AppTheme.text)
                .multilineTextAlignment(.trailing)
        }
    }

    private func primaryHandleRow(_ user: UserProfile) -> some View {
        HStack {
            Text("Primary handle")
                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                .foregroundStyle(AppTheme.mutedText)

            Spacer()

            if let primaryHandle = user.primaryHandle, !primaryHandle.isEmpty {
                CodeforcesHandleView(
                    handle: primaryHandle,
                    font: .system(.subheadline, design: .rounded).weight(.medium)
                )
            } else {
                Text("Not set")
                    .font(.system(.subheadline, design: .rounded).weight(.medium))
                    .foregroundStyle(AppTheme.text)
            }
        }
    }
}

private struct ProfileEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var sessionStore: SessionStore
    @StateObject private var viewModel: ProfileEditorViewModel
    @State private var isSaving = false

    init(profile: UserProfile) {
        _viewModel = StateObject(wrappedValue: ProfileEditorViewModel(profile: profile))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackdrop()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 18) {
                        fields

                        if let errorMessage = viewModel.errorMessage {
                            Text(errorMessage)
                                .font(.system(.footnote, design: .rounded))
                                .foregroundStyle(Color(red: 0.76, green: 0.21, blue: 0.22))
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task {
                            await saveProfile()
                        }
                    } label: {
                        if isSaving {
                            ProgressView()
                        } else {
                            Text("Save")
                                .font(.system(.headline, design: .rounded).weight(.bold))
                        }
                    }
                    .disabled(isSaving)
                }
            }
        }
    }

    private var fields: some View {
        VStack(alignment: .leading, spacing: 14) {
            TextField("Full name", text: $viewModel.fullName)
                .appInputField()

            TextField("Mobile number", text: $viewModel.mobileNumber)
                .keyboardType(.phonePad)
                .appInputField()

            TextField("University", text: $viewModel.universityName)
                .appInputField()

            TextField("Profile image URL", text: $viewModel.profileImageURLString)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .appInputField()

            TextField("Primary Codeforces handle", text: $viewModel.primaryHandle)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .appInputField()
        }
        .appCard()
    }

    private func saveProfile() async {
        isSaving = true
        defer { isSaving = false }

        do {
            try await sessionStore.updateProfile(viewModel.buildUpdatedProfile())
            dismiss()
        } catch {
            viewModel.errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    let session = SessionStore(previewUser: UserProfile(
        email: "demo@example.com",
        fullName: "Demo User",
        mobileNumber: "+8801000000000",
        universityName: "Demo University",
        primaryHandle: "tourist",
        friends: [
            FriendProfile(handle: "Benq")
        ]
    ))

    return NavigationStack {
        ProfileView()
            .environmentObject(session)
    }
}
