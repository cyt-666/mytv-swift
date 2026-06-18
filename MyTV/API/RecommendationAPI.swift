import Foundation

@MainActor enum RecommendationAPI {
    static func movies(limit: Int = 30) async throws -> [MovieDTO] {
        let cacheKey = "recommendations_movies_l\(limit)"
        if let cached: [MovieDTO] = CacheService.getAPIResponse(key: cacheKey) {
            return cached
        }
        let params: [String: String] = [
            "ignore_collected": "true",
            "ignore_watchlisted": "true",
            "limit": String(limit)
        ]

        let result: [MovieDTO] = try await TraktAPIClient.shared.request(
            uri: "/recommendations/movies",
            params: params,
            requiresAuth: true
        )
        CacheService.setAPIResponse(key: cacheKey, data: result)
        return result
    }

    static func shows(limit: Int = 30) async throws -> [ShowDTO] {
        let cacheKey = "recommendations_shows_l\(limit)"
        if let cached: [ShowDTO] = CacheService.getAPIResponse(key: cacheKey) {
            return cached
        }
        let params: [String: String] = [
            "ignore_collected": "true",
            "ignore_watchlisted": "true",
            "limit": String(limit)
        ]

        let result: [ShowDTO] = try await TraktAPIClient.shared.request(
            uri: "/recommendations/shows",
            params: params,
            requiresAuth: true
        )
        CacheService.setAPIResponse(key: cacheKey, data: result)
        return result
    }
}
