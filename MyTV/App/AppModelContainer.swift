import SwiftData

enum AppModelContainer {
    static func make() -> ModelContainer {
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
    }
}
