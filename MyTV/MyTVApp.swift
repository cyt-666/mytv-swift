import SwiftUI
import SwiftData

#if os(macOS)
@main
struct MyTVApp: App {
    @State private var appState = AppState()
    private let sharedModelContainer = AppModelContainer.make()

    var body: some Scene {
        WindowGroup {
            AppLocalizedRoot {
                ContentView()
                    .background(WindowAccessor { window in
                        window.backgroundColor = .clear
                        window.isOpaque = false
                    })
            }
            .environment(appState)
            .onAppear {
                let context = sharedModelContainer.mainContext
                CacheService.configure(context: context)
                AuthService.shared.configure(modelContext: context)
                CacheService.clearExpired()
                CacheService.invalidateUserDataOnLaunch()
                appState.refreshMediaAssistantConfiguration()
                MoviePilotNotificationService.shared.configure()
            }
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: AppConstants.defaultWindowWidth, height: AppConstants.defaultWindowHeight)
        .modelContainer(sharedModelContainer)
    }
}
#endif
