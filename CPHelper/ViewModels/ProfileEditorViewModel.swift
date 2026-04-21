import Combine
import Foundation

@MainActor
final class ProfileEditorViewModel: ObservableObject {
    @Published var fullName: String
    @Published var mobileNumber: String
    @Published var universityName: String
    @Published var profileImageURLString: String
    @Published var primaryHandle: String
    @Published var errorMessage: String?

    private let profile: UserProfile

    init(profile: UserProfile) {
        self.profile = profile
        self.fullName = profile.fullName
        self.mobileNumber = profile.mobileNumber
        self.universityName = profile.universityName
        self.profileImageURLString = profile.profileImageURLString
        self.primaryHandle = profile.primaryHandle ?? ""
    }

    func buildUpdatedProfile() -> UserProfile {
        UserProfile(
            id: profile.id,
            email: profile.email,
            fullName: fullName,
            mobileNumber: mobileNumber,
            universityName: universityName,
            profileImageURLString: profileImageURLString,
            primaryHandle: primaryHandle,
            friends: profile.friends,
            contestRegistrations: profile.contestRegistrations,
            todoProblems: profile.todoProblems,
            memberSince: profile.memberSince,
            updatedAt: .now
        )
    }
}
