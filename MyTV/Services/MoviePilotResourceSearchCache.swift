import Foundation

@MainActor
enum MoviePilotResourceSearchCache {
    private static let keyPrefix = "moviepilot_resource_search_v1:"

    static func load(for target: MoviePilotMediaTarget) -> MoviePilotResourceSearchSnapshot? {
        guard let key = cacheKey(for: target) else { return nil }
        return CacheService.getAPIResponse(key: key)
    }

    static func save(
        _ snapshot: MoviePilotResourceSearchSnapshot,
        for target: MoviePilotMediaTarget
    ) {
        guard let key = cacheKey(for: target) else { return }
        CacheService.setAPIResponse(
            key: key,
            data: snapshot,
            ttl: AppConstants.CacheTTL.moviePilotResourceSearch
        )
    }

    static func clearAll() {
        CacheService.removeAPIResponses(keyPrefix: keyPrefix)
    }

    private static func cacheKey(for target: MoviePilotMediaTarget) -> String? {
        guard let tmdbId = target.tmdbId else { return nil }
        let host = MoviePilotSettingsStore.host()
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        let encodedHost = Data(host.utf8).base64EncodedString()
        return "\(keyPrefix)\(encodedHost):\(target.kind.rawValue):\(tmdbId)"
    }
}
