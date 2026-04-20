import SwiftUI

struct FriendsView: View {
    @EnvironmentObject private var sessionStore: SessionStore

    @State private var selectedFriendID: UUID?
    @State private var analysis: HandleAnalysis?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var isAddingFriend = false

    private var selectedFriend: FriendProfile? {
        guard let selectedFriendID else { return sessionStore.currentUser?.friends.first }
        return sessionStore.currentUser?.friends.first(where: { $0.id == selectedFriendID })
    }

    var body: some View {
        ZStack {
            AppBackdrop()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    headerCard

                    if let selectedFriend {
                        if isLoading {
                            InlineMessageCard(
                                icon: "person.2.fill",
                                title: "Loading friend",
                                detail: "Fetching @\(selectedFriend.handle)."
                            )
                        } else if let errorMessage {
                            InlineMessageCard(
                                icon: "exclamationmark.triangle.fill",
                                title: "Could not load friend",
                                detail: errorMessage
                            )
                        } else if let analysis {
                            HandleAnalysisDashboard(analysis: analysis)
                        }
                    } else {
                        InlineMessageCard(
                            icon: "person.crop.circle.badge.plus",
                            title: "No friends yet",
                            detail: "Add a friend handle to start tracking."
                        )
                    }
                }
                .padding(20)
            }
        }
        .navigationTitle("Friends")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $isAddingFriend) {
            AddFriendSheet()
                .environmentObject(sessionStore)
        }
        .task(id: selectedFriend?.handle ?? "") {
            await loadSelectedFriend()
        }
        .onAppear {
            selectedFriendID = selectedFriendID ?? sessionStore.currentUser?.friends.first?.id
        }
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                SectionTitle(title: "Friend Profiles", subtitle: "Saved handles")
                Spacer()
                Button("Add") {
                    isAddingFriend = true
                }
                .buttonStyle(AppSecondaryButtonStyle())
            }

            if let friends = sessionStore.currentUser?.friends, !friends.isEmpty {
                Picker("Friend", selection: Binding(
                    get: { selectedFriendID ?? friends.first?.id ?? UUID() },
                    set: { selectedFriendID = $0 }
                )) {
                    ForEach(friends) { friend in
                        Text(friend.nickname.isEmpty ? friend.handle : "\(friend.nickname) • \(friend.handle)")
                            .tag(friend.id)
                    }
                }
                .pickerStyle(.menu)
                .tint(AppTheme.accent)

                if let selectedFriend {
                    HStack(spacing: 10) {
                        InfoBadge(title: selectedFriend.displayName, tint: AppTheme.accent)
                        Button("Remove") {
                            Task {
                                do {
                                    try await sessionStore.removeFriend(friendID: selectedFriend.id)
                                    selectedFriendID = sessionStore.currentUser?.friends.first?.id
                                    analysis = nil
                                } catch {
                                    errorMessage = error.localizedDescription
                                }
                            }
                        }
                        .buttonStyle(AppSecondaryButtonStyle())
                    }
                }
            }
        }
        .appCard()
    }

    private func loadSelectedFriend() async {
        guard let friend = selectedFriend else {
            analysis = nil
            errorMessage = nil
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            analysis = try await CodeforcesAnalysisService.shared.loadAnalysis(for: friend.handle)
            errorMessage = nil
        } catch {
            analysis = nil
            errorMessage = error.localizedDescription
        }
    }
}

private struct AddFriendSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var sessionStore: SessionStore

    @State private var handle = ""
    @State private var nickname = ""
    @State private var errorMessage: String?
    @State private var isSaving = false

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackdrop()

                VStack(alignment: .leading, spacing: 16) {
                    TextField("Handle", text: $handle)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .appInputField()

                    TextField("Nickname (optional)", text: $nickname)
                        .appInputField()

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.system(.footnote, design: .rounded))
                            .foregroundStyle(Color(red: 0.76, green: 0.21, blue: 0.22))
                    }

                    Button {
                        Task {
                            await save()
                        }
                    } label: {
                        if isSaving {
                            ProgressView().tint(.white)
                        } else {
                            Text("Save Friend")
                        }
                    }
                    .buttonStyle(AppPrimaryButtonStyle())
                }
                .padding(20)
            }
            .navigationTitle("Add Friend")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func save() async {
        let trimmedHandle = handle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedHandle.isEmpty else {
            errorMessage = "Enter a handle."
            return
        }

        isSaving = true
        defer { isSaving = false }

        do {
            try await sessionStore.addFriend(handle: trimmedHandle, nickname: nickname)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
