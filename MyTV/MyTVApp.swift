import SwiftUI
import SwiftData

@main
struct MyTVApp: App {
    @State private var appState = AppState()

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            AppConfig.self,
            MediaCache.self,
            APIResponseCache.self,
            UserDataCache.self,
            TranslationCache.self
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("无法创建 ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appState)
                .background(WindowAccessor { window in
                    window.backgroundColor = .clear
                    window.isOpaque = false
                    if let toolbar = window.toolbar {
                        toolbar.showsBaselineSeparator = false
                    }
                })
                .onAppear {
                    let context = sharedModelContainer.mainContext
                    CacheService.configure(context: context)
                    AuthService.shared.configure(modelContext: context)
                    CacheService.clearExpired()
                    CacheService.invalidateUserDataOnLaunch()
                }
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: AppConstants.defaultWindowWidth, height: AppConstants.defaultWindowHeight)
        .modelContainer(sharedModelContainer)
    }
}
