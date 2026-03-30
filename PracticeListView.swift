import SwiftUI

struct PracticeListView: View {
    @EnvironmentObject private var appData: AppData

    var body: some View {
        Group {
            if appData.savedProblems.isEmpty {
                emptyStateView
            } else {
                List {
                    ForEach(appData.savedProblems) { problem in
                        VStack(alignment: .leading, spacing: 10) {
                            Text(problem.name)
                                .font(.headline)

                            HStack {
                                Label("Rating \(problem.rating)", systemImage: "chart.bar.fill")
                                Spacer()
                                Label(problem.topic, systemImage: "tag.fill")
                            }
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                            Button {
                                appData.markAsPracticed(problem: problem)
                            } label: {
                                Text(appData.isPracticed(problem) ? "Practiced" : "Mark as Practiced")
                                    .fontWeight(.semibold)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(
                                        appData.isPracticed(problem) ? Color.green.opacity(0.18) : Color.green,
                                        in: RoundedRectangle(cornerRadius: 12)
                                    )
                                    .foregroundStyle(appData.isPracticed(problem) ? Color.green : Color.white)
                            }
                            .buttonStyle(.plain)
                            .disabled(appData.isPracticed(problem))
                        }
                        .padding(.vertical, 8)
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle("Practice List")
    }

    private var emptyStateView: some View {
        ScrollView {
            VStack(spacing: 14) {
                Image(systemName: "tray.fill")
                    .font(.system(size: 42))
                    .foregroundStyle(.blue)

                Text("No saved practice problems yet.")
                    .font(.title3)
                    .fontWeight(.semibold)

                Text("Save a problem from the Problem Picker screen to build your practice list.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(24)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(.secondarySystemBackground))
            )
            .padding()
        }
        .background(Color(.systemGroupedBackground))
    }
}

#Preview {
    NavigationStack {
        PracticeListView()
            .environmentObject(AppData())
    }
}
