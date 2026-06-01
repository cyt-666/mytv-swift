import Foundation

@MainActor enum MovieAPI {
    static func trending(page: Int = 1, limit: Int = 15, genres: String? = nil, countries: String? = nil) async throws -> [MovieTrendingDTO] {
        let cacheKey = "api_movie_trending_p\(page)_l\(limit)_g\(genres ?? "nil")_c\(countries ?? "nil")"
        if let cached: [MovieTrendingDTO] = CacheService.getAPIResponse(key: cacheKey) {
            return cached
        }
        var params = TraktEndpoint.movieTrending(page: page, limit: limit, genres: genres, countries: countries).defaultParams ?? [:]
        params.merge(TraktEndpoint.movieTrending(page: page, limit: limit, genres: genres, countries: countries).makePaginationParams(page: page, limit: limit)) { $1 }
        params.merge(TraktEndpoint.movieTrending(page: page, limit: limit, genres: genres, countries: countries).makeFilterParams(genres: genres, countries: countries)) { $1 }

        let result: [MovieTrendingDTO] = try await TraktAPIClient.shared.request(uri: "/movies/trending", params: params)
        CacheService.setAPIResponse(key: cacheKey, data: result)
        return result
    }

    static func popular(page: Int = 1, limit: Int = 15, genres: String? = nil, countries: String? = nil) async throws -> [MovieDTO] {
        let cacheKey = "api_movie_popular_p\(page)_l\(limit)_g\(genres ?? "nil")_c\(countries ?? "nil")"
        if let cached: [MovieDTO] = CacheService.getAPIResponse(key: cacheKey) {
            return cached
        }
        var params: [String: String] = ["extended": "full"]
        params.merge(TraktEndpoint.makePagination(page: page, limit: limit)) { $1 }
        params.merge(TraktEndpoint.makeFilter(genres: genres, countries: countries)) { $1 }

        let result: [MovieDTO] = try await TraktAPIClient.shared.request(uri: "/movies/popular", params: params)
        CacheService.setAPIResponse(key: cacheKey, data: result)
        return result
    }

    static func anticipated(page: Int = 1, limit: Int = 15, genres: String? = nil, countries: String? = nil) async throws -> [MovieAnticipatedDTO] {
        let cacheKey = "api_movie_anticipated_p\(page)_l\(limit)_g\(genres ?? "nil")_c\(countries ?? "nil")"
        if let cached: [MovieAnticipatedDTO] = CacheService.getAPIResponse(key: cacheKey) {
            return cached
        }
        var params: [String: String] = ["extended": "full"]
        params.merge(TraktEndpoint.makePagination(page: page, limit: limit)) { $1 }
        params.merge(TraktEndpoint.makeFilter(genres: genres, countries: countries)) { $1 }

        let result: [MovieAnticipatedDTO] = try await TraktAPIClient.shared.request(uri: "/movies/anticipated", params: params)
        CacheService.setAPIResponse(key: cacheKey, data: result)
        return result
    }

    static func details(id: Int) async throws -> MovieDetailsDTO {
        let cacheKey = "movie_details_\(id)"
        if let cached: (data: MovieDetailsDTO, isStale: Bool) = CacheService.getMediaCache(mediaType: "movie", traktId: id) {
            if cached.isStale {
                Task { _ = try? await fetchAndCacheDetails(id: id, cacheKey: cacheKey) }
            }
            return cached.data
        }
        return try await fetchAndCacheDetails(id: id, cacheKey: cacheKey)
    }

    private static func fetchAndCacheDetails(id: Int, cacheKey: String) async throws -> MovieDetailsDTO {
        let result: MovieDetailsDTO = try await TraktAPIClient.shared.request(
            uri: "/movies/\(id)",
            params: ["extended": "full,images"]
        )
        CacheService.setMediaCache(mediaType: "movie", traktId: id, data: result)
        return result
    }

    static func translations(id: Int, language: String = "zh") async throws -> [MovieTranslationDTO] {
        try await TraktAPIClient.shared.request(uri: "/movies/\(id)/translations/\(language)")
    }

    static func watched(period: String = "weekly", page: Int = 1, limit: Int = 15, genres: String? = nil, countries: String? = nil) async throws -> [MovieWatchedDTO] {
        let cacheKey = "api_movie_watched_\(period)_p\(page)_l\(limit)"
        if let cached: [MovieWatchedDTO] = CacheService.getAPIResponse(key: cacheKey) {
            return cached
        }
        var params: [String: String] = ["extended": "full,images"]
        params.merge(TraktEndpoint.makePagination(page: page, limit: limit)) { $1 }
        params.merge(TraktEndpoint.makeFilter(genres: genres, countries: countries)) { $1 }

        let result: [MovieWatchedDTO] = try await TraktAPIClient.shared.request(uri: "/movies/watched/\(period)", params: params)
        CacheService.setAPIResponse(key: cacheKey, data: result)
        return result
    }

    static func collected(period: String = "weekly", page: Int = 1, limit: Int = 15, genres: String? = nil, countries: String? = nil) async throws -> [MovieCollectedDTO] {
        let cacheKey = "api_movie_collected_\(period)_p\(page)_l\(limit)"
        if let cached: [MovieCollectedDTO] = CacheService.getAPIResponse(key: cacheKey) {
            return cached
        }
        var params: [String: String] = ["extended": "full,images"]
        params.merge(TraktEndpoint.makePagination(page: page, limit: limit)) { $1 }
        params.merge(TraktEndpoint.makeFilter(genres: genres, countries: countries)) { $1 }

        let result: [MovieCollectedDTO] = try await TraktAPIClient.shared.request(uri: "/movies/collected/\(period)", params: params)
        CacheService.setAPIResponse(key: cacheKey, data: result)
        return result
    }
}
