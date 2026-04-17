import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var sessionStore: SessionStore
    @State private var isEditing = false
    @State private var selectedRoute: HandleRoute?

    var body: some View {
        ZStack {
            AppBackdrop()

            if let user = sessionStore.currentUser {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 20) {
                        profileHeader(user: user)
                        profileDetails(user: user)
                        handlesSection(user: user)
                        signOutSection
                    }
                    .padding(20)
                }
            }
        }
        .navigationDestination(item: $selectedRoute) { route in
            HandleAnalysisView(handle: route.handle)
        }
        .sheet(isPresented: $isEditing) {
            if let user = sessionStore.currentUser {
                ProfileEditorSheet(profile: user)
                    .environmentObject(sessionStore)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Text("Profile")
                    .font(.system(.headline, design: .rounded).weight(.bold))
                    .foregroundStyle(AppTheme.text)
            }
        }
    }

    private func profileHeader(user: UserProfile) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 16) {
                ZStack {
                    Circle()
                        .fill(AppTheme.heroGradient)
                        .frame(width: 74, height: 74)

                    Text(user.initials)
                        .font(.system(.title2, design: .rounded).weight(.bold))
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(user.fullName)
                        .font(.system(.title2, design: .rounded).weight(.bold))
                        .foregroundStyle(AppTheme.text)

                    Text(user.email)
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(AppTheme.mutedText)

                    HStack(spacing: 8) {
                        InfoBadge(title: "\(user.handles.count) handles", tint: AppTheme.accent)

                        if let primaryHandle = user.primaryHandle {
                            InfoBadge(title: primaryHandle, tint: AppTheme.accentSecondary)
                        }
                    }
                }

                Spacer()
            }

            Button("Edit profile") {
                isEditing = true
            }
            .buttonStyle(AppPrimaryButtonStyle())
        }
        .appCard()
    }

    private func profileDetails(user: UserProfile) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionTitle(
                title: "Account details",
                subtitle: "Core personal info used across the app."
            )

            ProfileDetailRow(title: "Mobile", value: user.mobileNumber)
            ProfileDetailRow(title: "University", value: user.universityName.isEmpty ? "Not added" : user.universityName)
            ProfileDetailRow(title: "Member since", value: DateFormatting.mediumDate.string(from: user.memberSince))
        }
        .appCard()
    }

    private func handlesSection(user: UserProfile) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionTitle(
                title: "Tracked handles",
                subtitle: "Each handle has a direct analysis entry point."
            )

            if user.handles.isEmpty {
                Text("No handles added yet. Tap edit profile to add one or more Codeforces handles.")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(AppTheme.mutedText)
            } else {
                ForEach(user.handles) { handle in
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 8) {
                                Text(handle.handle)
                                    .font(.system(.headline, design: .rounded).weight(.bold))
                                    .foregroundStyle(AppTheme.text)

                                if handle.isPrimary {
                                    InfoBadge(title: "Primary", tint: AppTheme.accent)
                                }
                            }

                            Text(handle.label.isEmpty ? "Tracked handle" : handle.label)
                                .font(.system(.subheadline, design: .rounded))
                                .foregroundStyle(AppTheme.mutedText)
                        }

                        Spacer()

                        Button("View analysis") {
                            selectedRoute = HandleRoute(handle: handle.handle)
                        }
                        .buttonStyle(AppSecondaryButtonStyle())
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .appCard()
    }

    private var signOutSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionTitle(
                title: "Session",
                subtitle: "Use this if you want to switch to another local account."
            )

            Button(role: .destructive) {
                Task {
                    await sessionStore.signOut()
                }
            } label: {
                Text("Sign out")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(AppPrimaryButtonStyle())
        }
        .appCard()
    }
}

private struct ProfileDetailRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack(alignment: .top) {
            Text(title)
                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                .foregroundStyle(AppTheme.mutedText)

            Spacer()

            Text(value)
                .font(.system(.body, design: .rounded).weight(.medium))
                .foregroundStyle(AppTheme.text)
                .multilineTextAlignment(.trailing)
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
                    VStack(alignment: .leading, spacing: 20) {
                        profileFields
                        handleManager

                        if let errorMessage = viewModel.errorMessage {
                            Text(errorMessage)
                                .font(.system(.subheadline, design: .rounded))
                                .foregroundStyle(Color(red: 0.76, green: 0.21, blue: 0.21))
                                .padding(14)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .fill(Color.red.opacity(0.08))
                                )
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

    private var profileFields: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionTitle(
                title: "Profile info",
                subtitle: "Update the account information shown across the app."
            )

            TextField("Full name", text: $viewModel.fullName)
                .appInputField()

            TextField("Mobile number", text: $viewModel.mobileNumber)
                .keyboardType(.phonePad)
                .appInputField()

            TextField("University name", text: $viewModel.universityName)
                .appInputField()
        }
        .appCard()
    }

    private var handleManager: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionTitle(
                title: "Handle manager",
                subtitle: "Add multiple handles, set a primary one, or remove old entries."
            )

            ForEach(viewModel.handles) { handle in
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            Text(handle.handle)
                                .font(.system(.headline, design: .rounded).weight(.bold))
                                .foregroundStyle(AppTheme.text)

                            if handle.isPrimary {
                                InfoBadge(title: "Primary", tint: AppTheme.accent)
                            }
                        }

                        Text(handle.label.isEmpty ? "No custom label" : handle.label)
                            .font(.system(.subheadline, design: .rounded))
                            .foregroundStyle(AppTheme.mutedText)
                    }

                    Spacer()

                    Menu {
                        if !handle.isPrimary {
                            Button("Make primary") {
                                viewModel.makePrimary(handle)
                            }
                        }

                        Button(role: .destructive) {
                            viewModel.removeHandle(handle)
                        } label: {
                            Text("Remove")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(AppTheme.accent)
                    }
                }
                .padding(.vertical, 4)
            }

            Divider()

            TextField("New Codeforces handle", text: $viewModel.newHandleInput)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .appInputField()

            TextField("Label (optional)", text: $viewModel.newHandleLabelInput)
                .appInputField()

            Button("Add handle") {
                viewModel.addHandle()
            }
            .buttonStyle(AppSecondaryButtonStyle())
        }
        .appCard()
    }

    private func saveProfile() async {
        isSaving = true

        do {
            try await sessionStore.updateProfile(viewModel.buildUpdatedProfile())
            dismiss()
        } catch {
            viewModel.errorMessage = error.localizedDescription
        }

        isSaving = false
    }
}

#Preview {
    let session = SessionStore(previewUser: UserProfile(
        email: "demo@example.com",
        fullName: "Demo User",
        mobileNumber: "+8801000000000",
        universityName: "Demo University",
        handles: [
            TrackedHandle(handle: "tourist", label: "Main", isPrimary: true),
            TrackedHandle(handle: "neal", label: "Alt")
        ]
    ))

    return NavigationStack {
        ProfileView()
            .environmentObject(session)
    }
}
