import Foundation

@MainActor enum RecommendationAPI {
    static func movies(page: Int = 1, limit: Int = 30) async throws -> [MovieDTO] {
        let cacheKey = "recommendations_movies_p\(page)_l\(limit)"
        if let cached: [MovieDTO] = CacheService.getAPIResponse(key: cacheKey) {
            return cached
        }
        var params: [String: String] = ["ignore_collected": "true", "ignore_watched": "true"]
        params.merge(TraktEndpoint.makePagination(page: page, limit: limit)) { $1 }

        let result: [MovieDTO] = try await TraktAPIClient.shared.request(
            uri: "/recommendations/movies",
            params: params,
            requiresAuth: true
        )
        CacheService.setAPIResponse(key: cacheKey, data: result)
        return result
    }

    static func shows(page: Int = 1, limit: Int = 30) async throws -> [ShowDTO] {
        let cacheKey = "recommendations_shows_p\(page)_l\(limit)"
        if let cached: [ShowDTO] = CacheService.getAPIResponse(key: cacheKey) {
            return cached
        }
        var params: [String: String] = ["ignore_collected": "true", "ignore_watched": "true"]
        params.merge(TraktEndpoint.makePagination(page: page, limit: limit)) { $1 }

        let result: [ShowDTO] = try await TraktAPIClient.shared.request(
            uri: "/recommendations/shows",
            params: params,
            requiresAuth: true
        )
        CacheService.setAPIResponse(key: cacheKey, data: result)
        return result
    }
}
