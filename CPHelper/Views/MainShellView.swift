import SwiftUI

struct MainShellView: View {
    var body: some View {
        TabView {
            NavigationStack {
                HomeView()
            }
            .tabItem {
                Label("Home", systemImage: "house.fill")
            }

            NavigationStack {
                ToolkitView()
            }
            .tabItem {
                Label("Toolkit", systemImage: "sparkles.rectangle.stack.fill")
            }

            NavigationStack {
                ProfileView()
            }
            .tabItem {
                Label("Profile", systemImage: "person.crop.circle.fill")
            }
        }
        .tint(AppTheme.accent)
    }
}

#Preview {
    MainShellView()
        .environmentObject(AppData())
        .environmentObject(SessionStore())
}
