import Foundation

@MainActor enum RecommendationAPI {
    static func movies() async throws -> [MovieDTO] {
        let cacheKey = "recommendations_movies"
        if let cached: [MovieDTO] = CacheService.getAPIResponse(key: cacheKey) {
            return cached
        }
        let result: [MovieDTO] = try await TraktAPIClient.shared.request(
            uri: "/recommendations/movies",
            params: ["ignore_collected": "true", "ignore_watched": "true"],
            requiresAuth: true
        )
        CacheService.setAPIResponse(key: cacheKey, data: result)
        return result
    }

    static func shows() async throws -> [ShowDTO] {
        let cacheKey = "recommendations_shows"
        if let cached: [ShowDTO] = CacheService.getAPIResponse(key: cacheKey) {
            return cached
        }
        let result: [ShowDTO] = try await TraktAPIClient.shared.request(
            uri: "/recommendations/shows",
            params: ["ignore_collected": "true", "ignore_watched": "true"],
            requiresAuth: true
        )
        CacheService.setAPIResponse(key: cacheKey, data: result)
        return result
    }
}
