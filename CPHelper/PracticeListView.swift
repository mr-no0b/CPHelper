import SwiftUI

struct PracticeListView: View {
    @EnvironmentObject private var appData: AppData

    var body: some View {
        ZStack {
            AppBackdrop()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    if appData.savedProblems.isEmpty {
                        emptyStateView
                    } else {
                        ForEach(appData.savedProblems) { problem in
                            VStack(alignment: .leading, spacing: 10) {
                                Text(problem.name)
                                    .font(.system(.headline, design: .rounded).weight(.bold))
                                    .foregroundStyle(AppTheme.text)

                                HStack {
                                    Label("Rating \(problem.rating)", systemImage: "chart.bar.fill")
                                    Spacer()
                                    Label(problem.topic, systemImage: "tag.fill")
                                }
                                .font(.system(.subheadline, design: .rounded))
                                .foregroundStyle(AppTheme.mutedText)

                                Button {
                                    appData.markAsPracticed(problem: problem)
                                } label: {
                                    Text(appData.isPracticed(problem) ? "Practiced" : "Mark as Practiced")
                                }
                                .buttonStyle(AppSecondaryButtonStyle())
                                .disabled(appData.isPracticed(problem))
                            }
                            .appCard()
                        }
                    }
                }
                .padding(20)
            }
        }
        .navigationTitle("Practice List")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var emptyStateView: some View {
        VStack(spacing: 14) {
            Image(systemName: "tray.fill")
                .font(.system(size: 42))
                .foregroundStyle(AppTheme.accent)

            Text("No saved practice problems yet.")
                .font(.system(.title3, design: .rounded).weight(.bold))
                .foregroundStyle(AppTheme.text)

            Text("Save a problem from the Problem Picker screen to build your practice list.")
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(AppTheme.mutedText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .appCard()
    }
}

#Preview {
    NavigationStack {
        PracticeListView()
            .environmentObject(AppData())
    }
}
