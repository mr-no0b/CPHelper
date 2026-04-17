import Foundation

@MainActor
final class ProfileEditorViewModel: ObservableObject {
    @Published var fullName: String
    @Published var mobileNumber: String
    @Published var universityName: String
    @Published var handles: [TrackedHandle]
    @Published var newHandleInput: String = ""
    @Published var newHandleLabelInput: String = ""
    @Published var errorMessage: String?

    private let profile: UserProfile

    init(profile: UserProfile) {
        self.profile = profile
        self.fullName = profile.fullName
        self.mobileNumber = profile.mobileNumber
        self.universityName = profile.universityName
        self.handles = profile.handles
    }

    func addHandle() {
        errorMessage = nil

        let handle = newHandleInput.trimmingCharacters(in: .whitespacesAndNewlines)
        let label = newHandleLabelInput.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !handle.isEmpty else { return }

        guard !handles.contains(where: { $0.handle.caseInsensitiveCompare(handle) == .orderedSame }) else {
            errorMessage = AccountStoreError.duplicateHandle.localizedDescription
            return
        }

        handles.append(
            TrackedHandle(
                handle: handle,
                label: label,
                isPrimary: handles.isEmpty
            )
        )
        handles = handles.normalizedHandles()
        newHandleInput = ""
        newHandleLabelInput = ""
    }

    func removeHandle(_ handle: TrackedHandle) {
        handles.removeAll { $0.id == handle.id }
        handles = handles.normalizedHandles()
    }

    func makePrimary(_ handle: TrackedHandle) {
        handles = handles.map { current in
            var updated = current
            updated.isPrimary = current.id == handle.id
            return updated
        }.normalizedHandles()
    }

    func buildUpdatedProfile() -> UserProfile {
        UserProfile(
            id: profile.id,
            email: profile.email,
            fullName: fullName,
            mobileNumber: mobileNumber,
            universityName: universityName,
            handles: handles,
            todoProblems: profile.todoProblems,
            memberSince: profile.memberSince,
            updatedAt: .now
        )
    }
}
