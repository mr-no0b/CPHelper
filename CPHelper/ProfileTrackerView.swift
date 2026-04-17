
import SwiftUI

struct ProfileTrackerView: View {
    // Owns the profile loading logic for this screen.
    @StateObject private var viewModel = ProfileViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                inputCard
                statusCard

                if let profile = viewModel.profile {
                    profileSummaryCard(profile: profile)
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Profile Tracker")
    }

    private var inputCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Codeforces Handle", systemImage: "keyboard")
                .font(.headline)

            TextField("Enter handle", text: $viewModel.handleInput)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color(.systemBackground))
                )

            Button {
                viewModel.loadProfile()
            } label: {
                Text("Load Profile")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.blue, in: RoundedRectangle(cornerRadius: 14))
                    .foregroundStyle(.white)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.secondarySystemBackground))
        )
    }

    private var statusCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "info.circle.fill")
                .foregroundStyle(.blue)

            Text(viewModel.statusMessage)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
        )
    }

    private func profileSummaryCard(profile: CompetitiveProfile) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(profile.handle)
                        .font(.title2)
                        .fontWeight(.bold)

                    Text("Sample Codeforces summary")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "person.text.rectangle.fill")
                    .font(.system(size: 30))
                    .foregroundStyle(.blue)
            }

            Divider()

            summaryRow(title: "Current Rating", value: "\(profile.currentRating)")
            summaryRow(title: "Max Rating", value: "\(profile.maxRating)")
            summaryRow(title: "Solved Count", value: "\(profile.solvedCount)")
            summaryRow(title: "Strongest Topics", value: profile.strongestTopics.joined(separator: ", "))
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.secondarySystemBackground))
        )
    }

    private func summaryRow(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text(value)
                .font(.headline)
                .foregroundStyle(.primary)
        }
    }
}

#Preview {
    NavigationStack {
        ProfileTrackerView()
    }
}
