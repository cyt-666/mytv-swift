import Foundation

struct TranslationResult {
    let title: String?
    let overview: String?
    let tagline: String?
}

@MainActor
final class TranslationService {
    static let shared = TranslationService()

    private var memoryCache: [String: TranslationResult?] = [:]
    private var pendingRequests: [String: Task<TranslationResult?, Never>] = [:]
    private let semaphore = AsyncSemaphore(maxConcurrent: AppConstants.translationMaxConcurrent)

    func getMovieTranslation(id: Int) async -> TranslationResult? {
        let key = "movie_\(id)"
        return await getTranslation(key: key) { cacheKey in
            if let cached = Self.getFromDB(key: cacheKey) { return cached }
            let translations: [MovieTranslationDTO] = (try? await TraktAPIClient.shared.request(
                uri: "/movies/\(id)/translations/zh"
            )) ?? []
            let result = Self.selectPreferred(translations.map { (country: $0.country, title: $0.title, overview: $0.overview, tagline: $0.tagline) })
            if let result {
                CacheService.setTranslation(id: cacheKey, title: result.title, overview: result.overview, tagline: result.tagline)
            }
            return result
        }
    }

    func getShowTranslation(id: Int) async -> TranslationResult? {
        let key = "show_\(id)"
        return await getTranslation(key: key) { cacheKey in
            if let cached = Self.getFromDB(key: cacheKey) { return cached }
            let translations: [ShowTranslationDTO] = (try? await TraktAPIClient.shared.request(
                uri: "/shows/\(id)/translations/zh"
            )) ?? []
            let result = Self.selectPreferred(translations.map { (country: $0.country, title: $0.title, overview: $0.overview, tagline: $0.tagline) })
            if let result {
                CacheService.setTranslation(id: cacheKey, title: result.title, overview: result.overview, tagline: result.tagline)
            }
            return result
        }
    }

    func getSeasonTranslation(showId: Int, seasonNumber: Int) async -> TranslationResult? {
        let key = "season_\(showId)_\(seasonNumber)"
        return await getTranslation(key: key) { cacheKey in
            if let cached = Self.getFromDB(key: cacheKey) { return cached }
            let translations: [SeasonTranslationDTO] = (try? await TraktAPIClient.shared.request(
                uri: "/shows/\(showId)/seasons/\(seasonNumber)/translations/zh"
            )) ?? []
            let result = Self.selectPreferred(translations.map { (country: $0.country ?? "", title: $0.title ?? "", overview: $0.overview ?? "", tagline: nil as String?) })
            if let result {
                CacheService.setTranslation(id: cacheKey, title: result.title, overview: result.overview, tagline: result.tagline)
            }
            return result
        }
    }

    func getEpisodeTranslation(showId: Int, seasonNumber: Int, episodeNumber: Int) async -> TranslationResult? {
        let key = "episode_\(showId)_\(seasonNumber)_\(episodeNumber)"
        return await getTranslation(key: key) { cacheKey in
            if let cached = Self.getFromDB(key: cacheKey) { return cached }
            let translations: [EpisodeTranslationDTO] = (try? await TraktAPIClient.shared.request(
                uri: "/shows/\(showId)/seasons/\(seasonNumber)/episodes/\(episodeNumber)/translations/zh"
            )) ?? []
            let result = Self.selectPreferred(translations.map { (country: $0.country ?? "", title: $0.title ?? "", overview: $0.overview ?? "", tagline: nil as String?) })
            if let result {
                CacheService.setTranslation(id: cacheKey, title: result.title, overview: result.overview, tagline: result.tagline)
            }
            return result
        }
    }

    func clearCache() {
        memoryCache.removeAll()
        pendingRequests.removeAll()
    }

    // MARK: - Private

    private func getTranslation(key: String, fetcher: @escaping (String) async -> TranslationResult?) async -> TranslationResult? {
        if let cached = memoryCache[key] { return cached }

        if let pending = pendingRequests[key] { return await pending.value }

        let task = Task<TranslationResult?, Never> {
            await semaphore.wait()
            defer { Task { await semaphore.signal() } }
            return await fetcher(key)
        }
        pendingRequests[key] = task

        let result = await task.value
        memoryCache[key] = result
        pendingRequests[key] = nil

        if result == nil {
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(AppConstants.translationFailureCacheDuration))
                self.memoryCache.removeValue(forKey: key)
            }
        }

        return result
    }

    @MainActor private static func getFromDB(key: String) -> TranslationResult? {
        guard let cache = CacheService.getTranslation(id: key) else { return nil }
        return TranslationResult(title: cache.title, overview: cache.overview, tagline: cache.tagline)
    }

    /// Select translation with priority: cn > tw > hk > first available
    @MainActor private static func selectPreferred(_ translations: [(country: String, title: String, overview: String, tagline: String?)]) -> TranslationResult? {
        guard !translations.isEmpty else { return nil }

        let preferred = translations.first(where: { $0.country == "cn" })
            ?? translations.first(where: { $0.country == "tw" })
            ?? translations.first(where: { $0.country == "hk" })
            ?? translations.first

        guard let preferred else { return nil }
        return TranslationResult(title: preferred.title, overview: preferred.overview, tagline: preferred.tagline)
    }
}

// AsyncSemaphore for concurrency control
@MainActor
final class AsyncSemaphore {
    private var count: Int
    private var waiters: [CheckedContinuation<Void, Never>] = []

    init(maxConcurrent: Int) { self.count = maxConcurrent }

    func wait() async {
        if count > 0 { count -= 1; return }
        await withCheckedContinuation { waiters.append($0) }
    }

    func signal() {
        if let waiter = waiters.popLast() { waiter.resume() }
        else { count += 1 }
    }
}
