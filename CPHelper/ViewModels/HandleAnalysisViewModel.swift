import Foundation

@MainActor
final class HandleAnalysisViewModel: ObservableObject {
    @Published private(set) var analysis: HandleAnalysis?
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    let handle: String
    private let service: CodeforcesAnalysisService

    init(handle: String, service: CodeforcesAnalysisService = .shared) {
        self.handle = handle.trimmingCharacters(in: .whitespacesAndNewlines)
        self.service = service
    }

    func load(forceRefresh: Bool = false) async {
        guard !handle.isEmpty else {
            errorMessage = CodeforcesError.invalidHandle.localizedDescription
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            analysis = try await service.loadAnalysis(for: handle, forceRefresh: forceRefresh)
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}
