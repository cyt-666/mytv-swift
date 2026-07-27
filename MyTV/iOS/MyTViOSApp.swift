import SwiftData
import SwiftUI

#if os(iOS)
@main
struct MyTViOSApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @State private var appState = AppState()
    private let sharedModelContainer = AppModelContainer.make()

    var body: some Scene {
        WindowGroup {
            AppLocalizedRoot {
                IOSRootView()
            }
            .environment(appState)
            .modelContainer(sharedModelContainer)
            .onAppear {
                configureApp()
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .background {
                    MoviePilotNotificationService.shared.scheduleBackgroundRefreshIfNeeded()
                }
            }
        }
        .backgroundTask(.appRefresh(MoviePilotNotificationService.backgroundRefreshTaskIdentifier)) {
            await MoviePilotNotificationService.shared.performBackgroundRefresh()
        }
    }

    private func configureApp() {
        let context = sharedModelContainer.mainContext
        CacheService.configure(context: context)
        AuthService.shared.configure(modelContext: context)
        CacheService.clearExpired()
        CacheService.invalidateUserDataOnLaunch()
        appState.refreshMediaAssistantConfiguration()
        MoviePilotNotificationService.shared.configure()
    }
}
#endif
