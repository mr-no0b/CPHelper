import SwiftUI

@main
struct CompetitiveProgrammingHelperApp: App {
    @StateObject private var appData = AppData()
    @StateObject private var sessionStore = SessionStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appData)
                .environmentObject(sessionStore)
        }
    }
}
