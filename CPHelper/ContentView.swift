import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var sessionStore: SessionStore

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
    }
}

#Preview {
    ContentView()
        .environmentObject(AppData())
        .environmentObject(SessionStore())
}
