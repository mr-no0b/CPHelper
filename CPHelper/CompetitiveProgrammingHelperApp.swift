import SwiftUI

@main
struct CompetitiveProgrammingHelperApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var appRouter = AppRouter()
    @StateObject private var sessionStore = SessionStore()
    @StateObject private var tutorialLibrary = TutorialLibraryStore()
    @StateObject private var contestCenter = ContestCenterStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appRouter)
                .environmentObject(tutorialLibrary)
                .environmentObject(contestCenter)
                .environmentObject(sessionStore)
        }
    }
}
