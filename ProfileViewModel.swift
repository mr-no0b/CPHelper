
import Foundation
import Combine

final class ProfileViewModel: ObservableObject {
    @Published var handleInput: String = "tourist"
    @Published var profile: CompetitiveProfile?
    @Published var statusMessage: String = "Enter a sample handle and load a profile."

    func loadProfile() {
        let trimmedHandle = handleInput.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedHandle.isEmpty else {
            profile = nil
            statusMessage = "Please enter a Codeforces handle."
            return
        }

        let profiles: [CompetitiveProfile] = Bundle.main.decode("profiles.json")

        if let matchedProfile = profiles.first(where: { $0.handle.lowercased() == trimmedHandle.lowercased() }) {
            profile = matchedProfile
            statusMessage = "Loaded sample profile for \(matchedProfile.handle)."
        } else {
            profile = nil
            statusMessage = "No sample profile found. Try tourist, Benq, or neal."
        }
    }
}
