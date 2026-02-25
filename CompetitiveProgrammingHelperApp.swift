import SwiftUI

@main
struct CompetitiveProgrammingHelperApp: App {
    // Shared app state for problems, tutorials, and practice progress.
    @StateObject private var appData = AppData()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appData)
        }
    }
}
