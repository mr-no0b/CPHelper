import SwiftUI

struct MainShellView: View {
    @EnvironmentObject private var appRouter: AppRouter
    @EnvironmentObject private var contestCenter: ContestCenterStore

    @State private var isChatPresented = false
    @State private var isNotificationsPresented = false

    var body: some View {
        TabView(selection: $appRouter.selectedTab) {
            NavigationStack(path: $appRouter.homePath) {
                HomeView()
                    .navigationDestination(for: AppRouter.HomeDestination.self) { destination in
                        switch destination {
                        case .handleAnalysis(let handle):
                            HandleAnalysisView(handle: handle)
                        }
                    }
            }
            .tag(AppRouter.Tab.home)
            .tabItem {
                Label("Home", systemImage: "house.fill")
            }

            NavigationStack(path: $appRouter.toolkitPath) {
                ToolkitView()
                    .navigationDestination(for: AppRouter.ToolkitDestination.self) { destination in
                        switch destination {
                        case .tutorialList:
                            TutorialListView()
                        case .tutorialDetail(let tutorialID):
                            TutorialDetailContainerView(tutorialID: tutorialID)
                        case .contestCalendar:
                            ContestCalendarView()
                        }
                    }
            }
            .tag(AppRouter.Tab.toolkit)
            .tabItem {
                Label("Toolkit", systemImage: "sparkles.rectangle.stack.fill")
            }

            NavigationStack(path: $appRouter.profilePath) {
                ProfileView()
                    .navigationDestination(for: AppRouter.ProfileDestination.self) { destination in
                        switch destination {
                        case .handleAnalysis(let handle):
                            HandleAnalysisView(handle: handle)
                        }
                    }
            }
            .tag(AppRouter.Tab.profile)
            .tabItem {
                Label("Profile", systemImage: "person.crop.circle.fill")
            }
        }
        .tint(AppTheme.accent)
        .overlay(alignment: .bottomTrailing) {
            floatingUtilityStack
        }
        .sheet(isPresented: $isChatPresented) {
            NavigationStack {
                ChatbotWorkspaceView()
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $isNotificationsPresented) {
            NavigationStack {
                NotificationCenterView()
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .task {
            #if DEBUG
            if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" {
                return
            }
            #endif
            await contestCenter.requestAuthorizationIfNeeded()
        }
    }

    private var floatingUtilityStack: some View {
        VStack(spacing: 12) {
            Button {
                isNotificationsPresented = true
            } label: {
                ZStack(alignment: .topTrailing) {
                    floatingButton(
                        systemImage: "bell.fill",
                        label: "Notifications",
                        isProminent: false
                    )

                    if contestCenter.unreadCount > 0 {
                        Text("\(contestCenter.unreadCount)")
                            .font(.system(.caption2, design: .rounded).weight(.bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(
                                Capsule()
                                    .fill(Color(red: 0.83, green: 0.21, blue: 0.24))
                            )
                            .offset(x: 6, y: -6)
                    }
                }
            }
            .buttonStyle(.plain)

            Button {
                isChatPresented = true
            } label: {
                floatingButton(
                    systemImage: "message.fill",
                    label: "CP Coach",
                    isProminent: true
                )
            }
            .buttonStyle(.plain)
        }
        .padding(.trailing, 20)
        .padding(.bottom, 84)
    }

    private func floatingButton(
        systemImage: String,
        label: String,
        isProminent: Bool
    ) -> some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: isProminent ? 18 : 16, weight: .semibold))

            Text(label)
                .font(.system(.subheadline, design: .rounded).weight(.bold))
        }
        .foregroundStyle(isProminent ? .white : AppTheme.text)
        .padding(.horizontal, 18)
        .padding(.vertical, isProminent ? 16 : 14)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(isProminent ? AnyShapeStyle(AppTheme.heroGradient) : AnyShapeStyle(Color.white.opacity(0.95)))
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(AppTheme.cardBorder, lineWidth: isProminent ? 0 : 1)
                )
                .shadow(color: Color.black.opacity(0.12), radius: 20, x: 0, y: 12)
        )
    }
}

#Preview {
    MainShellView()
        .environmentObject(AppData())
        .environmentObject(AppRouter())
        .environmentObject(TutorialLibraryStore())
        .environmentObject(ContestCenterStore())
        .environmentObject(SessionStore())
}
