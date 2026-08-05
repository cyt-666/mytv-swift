import Foundation
import SwiftData

enum CacheService {
    @MainActor private static var modelContext: ModelContext?

    @MainActor static func configure(context: ModelContext) {
        self.modelContext = context
    }

    // MARK: - Media Cache

    @MainActor static func getMediaCache<T: Decodable>(mediaType: String, traktId: Int) -> (data: T, isStale: Bool)? {
        guard let modelContext else { return nil }
        let id = "\(mediaType)_\(traktId)"
        let now = Date()

        let descriptor = FetchDescriptor<MediaCache>(predicate: #Predicate { $0.id == id })
        guard let results = try? modelContext.fetch(descriptor), let cache = results.first else {
            return nil
        }

        if now > cache.expiresAt {
            modelContext.delete(cache)
            try? modelContext.save()
            return nil
        }

        let isStale = cache.updatedAt.addingTimeInterval(AppConstants.CacheTTL.staleWhileRevalidate) < now

        guard let decoded = try? JSONDecoder().decode(T.self, from: cache.data) else { return nil }
        return (decoded, isStale)
    }

    @MainActor static func setMediaCache(mediaType: String, traktId: Int, data: some Encodable, ttl: TimeInterval = AppConstants.CacheTTL.long) {
        guard let modelContext else { return }
        let id = "\(mediaType)_\(traktId)"
        let now = Date()

        guard let encoded = try? JSONEncoder().encode(data) else { return }

        try? modelContext.delete(model: MediaCache.self, where: #Predicate { $0.id == id })

        let cache = MediaCache(
            id: id,
            mediaType: mediaType,
            traktId: traktId,
            data: encoded,
            updatedAt: now,
            expiresAt: now.addingTimeInterval(ttl)
        )
        modelContext.insert(cache)
        try? modelContext.save()
    }

    // MARK: - API Response Cache

    @MainActor static func getAPIResponse<T: Decodable>(key: String) -> T? {
        guard let modelContext else { return nil }
        let now = Date()

        let descriptor = FetchDescriptor<APIResponseCache>(predicate: #Predicate { $0.key == key })
        guard let results = try? modelContext.fetch(descriptor), let cache = results.first else {
            return nil
        }

        if now > cache.expiresAt {
            modelContext.delete(cache)
            try? modelContext.save()
            return nil
        }

        return try? JSONDecoder().decode(T.self, from: cache.data)
    }

    @MainActor static func setAPIResponse(key: String, data: some Encodable, ttl: TimeInterval = AppConstants.CacheTTL.apiList) {
        guard let modelContext else { return }
        let now = Date()

        guard let encoded = try? JSONEncoder().encode(data) else { return }

        try? modelContext.delete(model: APIResponseCache.self, where: #Predicate { $0.key == key })

        let cache = APIResponseCache(
            key: key,
            data: encoded,
            updatedAt: now,
            expiresAt: now.addingTimeInterval(ttl)
        )
        modelContext.insert(cache)
        try? modelContext.save()
    }

    @MainActor static func removeAPIResponses(keyPrefix: String) {
        guard let modelContext else { return }
        let descriptor = FetchDescriptor<APIResponseCache>()
        guard let entries = try? modelContext.fetch(descriptor) else { return }
        for entry in entries where entry.key.hasPrefix(keyPrefix) {
            modelContext.delete(entry)
        }
        try? modelContext.save()
    }

    // MARK: - User Data Cache

    @MainActor static func getUserData<T: Decodable>(key: String) -> (data: T, isStale: Bool)? {
        guard let modelContext else { return nil }
        let now = Date()

        let descriptor = FetchDescriptor<UserDataCache>(predicate: #Predicate { $0.key == key })
        guard let results = try? modelContext.fetch(descriptor), let cache = results.first else {
            return nil
        }

        let isStale = cache.updatedAt.addingTimeInterval(AppConstants.CacheTTL.staleWhileRevalidateUser) < now

        guard let decoded = try? JSONDecoder().decode(T.self, from: cache.data) else { return nil }
        return (decoded, isStale)
    }

    @MainActor static func setUserData(key: String, data: some Encodable) {
        guard let modelContext else { return }
        let now = Date()

        guard let encoded = try? JSONEncoder().encode(data) else { return }

        try? modelContext.delete(model: UserDataCache.self, where: #Predicate { $0.key == key })

        let cache = UserDataCache(key: key, data: encoded, updatedAt: now)
        modelContext.insert(cache)
        try? modelContext.save()
    }

    // MARK: - Translation Cache

    @MainActor static func getTranslation(id: String) -> TranslationCache? {
        guard let modelContext else { return nil }
        let now = Date()

        let descriptor = FetchDescriptor<TranslationCache>(predicate: #Predicate { $0.id == id })
        guard let results = try? modelContext.fetch(descriptor), let cache = results.first else {
            return nil
        }

        if now > cache.expiresAt {
            modelContext.delete(cache)
            try? modelContext.save()
            return nil
        }

        return cache
    }

    @MainActor static func setTranslation(id: String, title: String?, overview: String?, tagline: String?) {
        guard let modelContext else { return }
        let now = Date()

        try? modelContext.delete(model: TranslationCache.self, where: #Predicate { $0.id == id })

        let cache = TranslationCache(
            id: id,
            title: title,
            overview: overview,
            tagline: tagline,
            updatedAt: now,
            expiresAt: now.addingTimeInterval(AppConstants.CacheTTL.translation)
        )
        modelContext.insert(cache)
        try? modelContext.save()
    }

    // MARK: - Config

    @MainActor static func getConfig(key: String) -> Data? {
        guard let modelContext else { return nil }
        let descriptor = FetchDescriptor<AppConfig>(predicate: #Predicate { $0.key == key })
        return try? modelContext.fetch(descriptor).first?.value
    }

    @MainActor static func setConfig(key: String, value: Data) {
        guard let modelContext else { return }
        try? modelContext.delete(model: AppConfig.self, where: #Predicate { $0.key == key })
        let config = AppConfig(key: key, value: value)
        modelContext.insert(config)
        try? modelContext.save()
    }

    // MARK: - Manual refresh

    @MainActor static func clearAllAPIResponses() {
        guard let modelContext else { return }
        try? modelContext.delete(model: APIResponseCache.self, where: #Predicate { _ in true })
        try? modelContext.save()
    }

    @MainActor static func clearAPIResponses(containing text: String) {
        guard let modelContext else { return }
        try? modelContext.delete(model: APIResponseCache.self, where: #Predicate { $0.key.contains(text) })
        try? modelContext.save()
    }

    @MainActor static func clearUserData(containing text: String) {
        guard let modelContext else { return }
        try? modelContext.delete(model: UserDataCache.self, where: #Predicate { $0.key.contains(text) })
        try? modelContext.save()
    }

    @MainActor static func invalidateWatchedData() {
        clearAPIResponses(containing: "user_history")
        clearAPIResponses(containing: "user_watched")
        clearAPIResponses(containing: "up_next")
        clearAPIResponses(containing: "api_movie_watched")
        clearAPIResponses(containing: "api_show_watched")
        clearUserData(containing: "user_stats")
    }

    // MARK: - Session invalidation

    /// Mark user data caches as stale so SWR triggers a background refresh on next read
    @MainActor static func invalidateUserDataOnLaunch() {
        guard let modelContext else { return }
        // Delete up-next cache (short-lived, always refresh)
        try? modelContext.delete(model: APIResponseCache.self, where: #Predicate { $0.key == "up_next_items" })
        // Delete history caches
        try? modelContext.delete(model: APIResponseCache.self, where: #Predicate { $0.key.contains("user_history") })
        // Delete watchlist caches
        try? modelContext.delete(model: APIResponseCache.self, where: #Predicate { $0.key.contains("user_watchlist") })
        // Reset user data updatedAt so SWR treats them as stale
        let now = Date()
        let staleThreshold = now.addingTimeInterval(-1)
        let descriptor = FetchDescriptor<UserDataCache>(predicate: #Predicate { $0.updatedAt < staleThreshold })
        if let results = try? modelContext.fetch(descriptor) {
            for cache in results {
                cache.updatedAt = Date.distantPast
            }
        }
        try? modelContext.save()
    }

    // MARK: - Cleanup

    @MainActor static func clearExpired() {
        guard let modelContext else { return }
        let now = Date()

        try? modelContext.delete(model: MediaCache.self, where: #Predicate { $0.expiresAt < now })
        try? modelContext.delete(model: APIResponseCache.self, where: #Predicate { $0.expiresAt < now })
        try? modelContext.delete(model: TranslationCache.self, where: #Predicate { $0.expiresAt < now })

        try? modelContext.save()
    }
}
