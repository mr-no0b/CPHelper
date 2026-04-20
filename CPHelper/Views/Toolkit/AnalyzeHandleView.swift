import SwiftUI

struct AnalyzeHandleView: View {
    @State private var handleInput = ""
    @State private var analysis: HandleAnalysis?
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            AppBackdrop()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 14) {
                        SectionTitle(title: "Analyze Handle", subtitle: "Any public handle")

                        TextField("tourist", text: $handleInput)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .appInputField()

                        Button("Analyze") {
                            Task {
                                await analyze()
                            }
                        }
                        .buttonStyle(AppPrimaryButtonStyle())
                    }
                    .appCard()

                    if isLoading {
                        InlineMessageCard(
                            icon: "chart.line.uptrend.xyaxis",
                            title: "Loading analysis",
                            detail: "Fetching Codeforces data."
                        )
                    } else if let errorMessage {
                        InlineMessageCard(
                            icon: "exclamationmark.triangle.fill",
                            title: "Could not analyze",
                            detail: errorMessage
                        )
                    } else if let analysis {
                        HandleAnalysisDashboard(analysis: analysis)
                    }
                }
                .padding(20)
            }
        }
        .navigationTitle("Analyze")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func analyze() async {
        let handle = handleInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !handle.isEmpty else {
            errorMessage = "Enter a handle."
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            analysis = try await CodeforcesAnalysisService.shared.loadAnalysis(for: handle, forceRefresh: true)
            errorMessage = nil
        } catch {
            analysis = nil
            errorMessage = error.localizedDescription
        }
    }
}
