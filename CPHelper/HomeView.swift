import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var sessionStore: SessionStore
    @State private var handleInput = ""
    @State private var selectedRoute: HandleRoute?
    @State private var searchHint: String?

    var body: some View {
        ZStack {
            AppBackdrop()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    heroSection
                    quickAnalysisCard
                    trackedHandlesSection
                    workspaceSection
                }
                .padding(20)
            }
        }
        .navigationDestination(item: $selectedRoute) { route in
            HandleAnalysisView(handle: route.handle)
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Text("Home")
                    .font(.system(.headline, design: .rounded).weight(.bold))
                    .foregroundStyle(AppTheme.text)
            }
        }
    }

    private var heroSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Welcome back, \(sessionStore.currentUser?.fullName.components(separatedBy: " ").first ?? "coder").")
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(AppTheme.text)

            Text("Search any Codeforces handle, revisit your tracked profiles, and keep the rest of the helper tools one tap away.")
                .font(.system(.body, design: .rounded))
                .foregroundStyle(AppTheme.mutedText)

            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 10) {
                    MetricChip(title: "Tracked", value: "\(sessionStore.currentUser?.handles.count ?? 0)")
                    MetricChip(title: "Default", value: sessionStore.currentUser?.primaryHandle ?? "None")
                }

                HStack(spacing: 10) {
                    MetricChip(
                        title: "Member since",
                        value: sessionStore.currentUser.map {
                            DateFormatting.mediumDate.string(from: $0.memberSince)
                        } ?? "Today"
                    )
                    MetricChip(title: "Analysis", value: "Live CF")
                }
            }

            if let primaryHandle = sessionStore.currentUser?.primaryHandle {
                HStack(spacing: 12) {
                    Text("Primary handle: \(primaryHandle)")
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        .foregroundStyle(.white)

                    Spacer()

                    Button("Open analysis") {
                        openHandle(primaryHandle)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.white.opacity(0.20))
                    .foregroundStyle(.white)
                }
                .padding(18)
                .background(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(AppTheme.heroGradient)
                )
            }
        }
    }

    private var quickAnalysisCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionTitle(
                title: "Handle analysis",
                subtitle: "Type any public Codeforces handle and jump into a full breakdown."
            )

            TextField("Enter a handle like tourist", text: $handleInput)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .appInputField()

            if let searchHint {
                Text(searchHint)
                    .font(.system(.footnote, design: .rounded))
                    .foregroundStyle(Color(red: 0.74, green: 0.24, blue: 0.22))
            }

            Button("Analyze handle") {
                let normalized = handleInput.trimmingCharacters(in: .whitespacesAndNewlines)

                guard !normalized.isEmpty else {
                    searchHint = "Please enter a Codeforces handle."
                    return
                }

                searchHint = nil
                openHandle(normalized)
            }
            .buttonStyle(AppPrimaryButtonStyle())
        }
        .appCard()
    }

    private var trackedHandlesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionTitle(
                title: "Tracked handles",
                subtitle: "These are pinned to your profile for one-tap access."
            )

            if let handles = sessionStore.currentUser?.handles, !handles.isEmpty {
                ForEach(handles) { handle in
                    HStack(spacing: 14) {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 8) {
                                Text(handle.handle)
                                    .font(.system(.headline, design: .rounded).weight(.bold))
                                    .foregroundStyle(AppTheme.text)

                                if handle.isPrimary {
                                    InfoBadge(title: "Primary", tint: AppTheme.accent)
                                }
                            }

                            if !handle.label.isEmpty {
                                Text(handle.label)
                                    .font(.system(.subheadline, design: .rounded))
                                    .foregroundStyle(AppTheme.mutedText)
                            }
                        }

                        Spacer()

                        Button("View analysis") {
                            openHandle(handle.handle)
                        }
                        .buttonStyle(AppSecondaryButtonStyle())
                    }
                    .appCard()
                }
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    Text("No handles added yet.")
                        .font(.system(.headline, design: .rounded).weight(.bold))
                        .foregroundStyle(AppTheme.text)

                    Text("Open the Profile tab to add your Codeforces handles and start tracking them.")
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(AppTheme.mutedText)
                }
                .appCard()
            }
        }
    }

    private var workspaceSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionTitle(
                title: "Keep building",
                subtitle: "Your older helper tools are still here, now wrapped in the new workspace."
            )

            NavigationLink(destination: ToolkitView()) {
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Open toolkit")
                            .font(.system(.headline, design: .rounded).weight(.bold))
                            .foregroundStyle(AppTheme.text)

                        Text("Problem picker, practice list, and tutorial hub.")
                            .font(.system(.subheadline, design: .rounded))
                            .foregroundStyle(AppTheme.mutedText)
                    }

                    Spacer()

                    Image(systemName: "arrow.right.circle.fill")
                        .font(.system(size: 26))
                        .foregroundStyle(AppTheme.accent)
                }
                .appCard()
            }
            .buttonStyle(.plain)
        }
    }

    private func openHandle(_ handle: String) {
        selectedRoute = HandleRoute(handle: handle)
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
            TrackedHandle(handle: "Benq", label: "Reference")
        ]
    ))

    return NavigationStack {
        HomeView()
            .environmentObject(AppData())
            .environmentObject(session)
    }
}
