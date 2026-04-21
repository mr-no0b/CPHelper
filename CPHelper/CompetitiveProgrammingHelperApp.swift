import SwiftUI
import FirebaseCore

@main
struct CompetitiveProgrammingHelperApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var appRouter: AppRouter
    @StateObject private var sessionStore: SessionStore
    @StateObject private var tutorialLibrary: TutorialLibraryStore
    @StateObject private var contestCenter: ContestCenterStore

    init() {
        _appRouter = StateObject(wrappedValue: AppRouter())
        _sessionStore = StateObject(wrappedValue: SessionStore())
        _tutorialLibrary = StateObject(wrappedValue: TutorialLibraryStore())
        _contestCenter = StateObject(wrappedValue: ContestCenterStore())
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appRouter)
                .environmentObject(tutorialLibrary)
                .environmentObject(contestCenter)
                .environmentObject(sessionStore)
                .task {
                    await sessionStore.restoreSessionIfNeeded()
                }
        }
    }
}
