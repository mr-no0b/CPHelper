import Combine
import Foundation

@MainActor
final class AppRouter: ObservableObject {
    enum Tab: Hashable {
        case home
        case toolkit
        case profile
    }

    enum HomeDestination: Hashable {
        case handleAnalysis(String)
    }

    enum ToolkitDestination: Hashable {
        case tutorialList
        case tutorialDetail(String)
        case contestCalendar
    }

    enum ProfileDestination: Hashable {
        case handleAnalysis(String)
    }

    @Published var selectedTab: Tab = .home
    @Published var homePath: [HomeDestination] = []
    @Published var toolkitPath: [ToolkitDestination] = []
    @Published var profilePath: [ProfileDestination] = []

    func openHandleAnalysis(_ handle: String) {
        let normalized = handle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return }

        selectedTab = .home
        homePath = [.handleAnalysis(normalized)]
    }

    func openTutorialHub() {
        selectedTab = .toolkit
        toolkitPath = [.tutorialList]
    }

    func openTutorial(id: String) {
        guard !id.isEmpty else { return }

        selectedTab = .toolkit
        toolkitPath = [.tutorialDetail(id)]
    }

    func openContestCalendar() {
        selectedTab = .toolkit
        toolkitPath = [.contestCalendar]
    }
}
