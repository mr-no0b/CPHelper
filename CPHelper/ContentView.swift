import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var contestCenter: ContestCenterStore
    @EnvironmentObject private var sessionStore: SessionStore
    @EnvironmentObject private var tutorialLibrary: TutorialLibraryStore

    var body: some View {
        Group {
            if sessionStore.isBootstrapping {
                ZStack {
                    AppBackdrop()

                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.2)
                            .tint(AppTheme.accent)

                        Text("Preparing your workspace...")
                            .font(.system(.headline, design: .rounded).weight(.bold))
                            .foregroundStyle(AppTheme.text)
                    }
                }
            } else if sessionStore.isAuthenticated {
                MainShellView()
            } else {
                AuthView()
            }
        }
        .task(id: sessionStore.currentUser?.email ?? "guest") {
            await tutorialLibrary.loadIfNeeded()
            await contestCenter.refresh(for: sessionStore.currentUser, force: true)
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AppRouter())
        .environmentObject(TutorialLibraryStore())
        .environmentObject(ContestCenterStore())
        .environmentObject(SessionStore())
}
