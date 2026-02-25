import SwiftUI

struct HomeView: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    headerSection

                    VStack(spacing: 16) {
                        NavigationLink(destination: ProfileTrackerView()) {
                            DashboardCard(
                                title: "Profile Tracker",
                                subtitle: "Load a sample Codeforces profile summary.",
                                iconName: "person.crop.circle.fill",
                                tintColor: .blue
                            )
                        }

                        NavigationLink(destination: ProblemPickerView()) {
                            DashboardCard(
                                title: "Problem Picker",
                                subtitle: "Filter local problems and get a recommendation.",
                                iconName: "list.bullet.clipboard.fill",
                                tintColor: .orange
                            )
                        }

                        NavigationLink(destination: PracticeListView()) {
                            DashboardCard(
                                title: "Practice List",
                                subtitle: "Review saved problems and mark practice done.",
                                iconName: "list.bullet.rectangle.portrait.fill",
                                tintColor: .green
                            )
                        }

                        NavigationLink(destination: TutorialListView()) {
                            DashboardCard(
                                title: "Algorithm Tutorials",
                                subtitle: "Read short topic notes for core techniques.",
                                iconName: "book.closed.fill",
                                tintColor: .purple
                            )
                        }
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Dashboard")
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Competitive Programming Helper")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("Track progress and practice smarter")
                .font(.headline)
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                Image(systemName: "bolt.shield.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(.white)
                    .frame(width: 56, height: 56)
                    .background(Color.blue.gradient, in: RoundedRectangle(cornerRadius: 16))

                Text("A clean student-friendly dashboard for profile tracking, problem practice, and quick algorithm notes.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(.secondarySystemBackground))
            )
        }
    }
}

private struct DashboardCard: View {
    let title: String
    let subtitle: String
    let iconName: String
    let tintColor: Color

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: iconName)
                .font(.system(size: 24))
                .foregroundStyle(tintColor)
                .frame(width: 56, height: 56)
                .background(tintColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 16))

            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)

                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .foregroundStyle(.tertiary)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.secondarySystemBackground))
        )
    }
}

#Preview {
    HomeView()
        .environmentObject(AppData())
}
