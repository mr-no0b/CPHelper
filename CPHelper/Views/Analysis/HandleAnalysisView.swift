import SwiftUI

struct HandleAnalysisView: View {
    @StateObject private var viewModel: HandleAnalysisViewModel

    init(handle: String) {
        _viewModel = StateObject(wrappedValue: HandleAnalysisViewModel(handle: handle))
    }

    var body: some View {
        ZStack {
            AppBackdrop()

            Group {
                if let analysis = viewModel.analysis {
                    ScrollView(showsIndicators: false) {
                        HandleAnalysisDashboard(analysis: analysis)
                            .padding(20)
                    }
                } else if viewModel.isLoading {
                    loadingState
                } else if let errorMessage = viewModel.errorMessage {
                    errorState(message: errorMessage)
                } else {
                    loadingState
                }
            }
        }
        .navigationTitle(viewModel.handle)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if viewModel.analysis == nil && !viewModel.isLoading {
                await viewModel.load()
            }
        }
        .refreshable {
            await viewModel.load(forceRefresh: true)
        }
    }

    private var loadingState: some View {
        VStack(spacing: 14) {
            ProgressView()
                .scaleEffect(1.2)
                .tint(AppTheme.accent)

            Text("Loading analysis...")
                .font(.system(.headline, design: .rounded).weight(.bold))
                .foregroundStyle(AppTheme.text)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorState(message: String) -> some View {
        VStack(spacing: 14) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 36))
                .foregroundStyle(AppTheme.warning)

            Text(message)
                .font(.system(.body, design: .rounded))
                .foregroundStyle(AppTheme.text)
                .multilineTextAlignment(.center)

            Button("Retry") {
                Task {
                    await viewModel.load(forceRefresh: true)
                }
            }
            .buttonStyle(AppPrimaryButtonStyle())
            .frame(maxWidth: 220)
        }
        .padding(24)
    }
}

#Preview {
    NavigationStack {
        HandleAnalysisView(handle: "tourist")
    }
}
