import Foundation

@MainActor enum ShowAPI {
    static func trending(page: Int = 1, limit: Int = 15, genres: String? = nil, countries: String? = nil) async throws -> [ShowTrendingDTO] {
        let cacheKey = "api_show_trending_p\(page)_l\(limit)_g\(genres ?? "nil")_c\(countries ?? "nil")"
        if let cached: [ShowTrendingDTO] = CacheService.getAPIResponse(key: cacheKey) {
            return cached
        }
        var params: [String: String] = ["extended": "full,images"]
        params.merge(TraktEndpoint.makePagination(page: page, limit: limit)) { $1 }
        params.merge(TraktEndpoint.makeFilter(genres: genres, countries: countries)) { $1 }

        let result: [ShowTrendingDTO] = try await TraktAPIClient.shared.request(uri: "/shows/trending", params: params)
        CacheService.setAPIResponse(key: cacheKey, data: result)
        return result
    }

    static func popular(page: Int = 1, limit: Int = 15, genres: String? = nil, countries: String? = nil) async throws -> [ShowDTO] {
        let cacheKey = "api_show_popular_p\(page)_l\(limit)_g\(genres ?? "nil")_c\(countries ?? "nil")"
        if let cached: [ShowDTO] = CacheService.getAPIResponse(key: cacheKey) {
            return cached
        }
        var params: [String: String] = ["extended": "full,images"]
        params.merge(TraktEndpoint.makePagination(page: page, limit: limit)) { $1 }
        params.merge(TraktEndpoint.makeFilter(genres: genres, countries: countries)) { $1 }

        let result: [ShowDTO] = try await TraktAPIClient.shared.request(uri: "/shows/popular", params: params)
        CacheService.setAPIResponse(key: cacheKey, data: result)
        return result
    }

    static func anticipated(page: Int = 1, limit: Int = 15, genres: String? = nil, countries: String? = nil) async throws -> [ShowAnticipatedDTO] {
        let cacheKey = "api_show_anticipated_p\(page)_l\(limit)_g\(genres ?? "nil")_c\(countries ?? "nil")"
        if let cached: [ShowAnticipatedDTO] = CacheService.getAPIResponse(key: cacheKey) {
            return cached
        }
        var params: [String: String] = ["extended": "full,images"]
        params.merge(TraktEndpoint.makePagination(page: page, limit: limit)) { $1 }
        params.merge(TraktEndpoint.makeFilter(genres: genres, countries: countries)) { $1 }

        let result: [ShowAnticipatedDTO] = try await TraktAPIClient.shared.request(uri: "/shows/anticipated", params: params)
        CacheService.setAPIResponse(key: cacheKey, data: result)
        return result
    }

    static func details(id: Int) async throws -> ShowDetailsDTO {
        if let cached: (data: ShowDetailsDTO, isStale: Bool) = CacheService.getMediaCache(mediaType: "show", traktId: id) {
            if cached.isStale {
                Task { _ = try? await fetchAndCacheDetails(id: id) }
            }
            return cached.data
        }
        return try await fetchAndCacheDetails(id: id)
    }

    private static func fetchAndCacheDetails(id: Int) async throws -> ShowDetailsDTO {
        let result: ShowDetailsDTO = try await TraktAPIClient.shared.request(
            uri: "/shows/\(id)",
            params: ["extended": "full,images"]
        )
        CacheService.setMediaCache(mediaType: "show", traktId: id, data: result)
        return result
    }

    static func seasons(id: Int) async throws -> [SeasonDTO] {
        if let cached: (data: [SeasonDTO], isStale: Bool) = CacheService.getMediaCache(mediaType: "show_seasons", traktId: id) {
            return cached.data
        }
        let result: [SeasonDTO] = try await TraktAPIClient.shared.request(
            uri: "/shows/\(id)/seasons",
            params: ["extended": "full"]
        )
        CacheService.setMediaCache(mediaType: "show_seasons", traktId: id, data: result)
        return result
    }

    static func seasonEpisodes(showId: Int, seasonNumber: Int) async throws -> [EpisodeDTO] {
        let result: [EpisodeDTO] = try await TraktAPIClient.shared.request(
            uri: "/shows/\(showId)/seasons/\(seasonNumber)",
            params: ["extended": "full"]
        )
        return result
    }

    static func episodeDetails(showId: Int, seasonNumber: Int, episodeNumber: Int) async throws -> EpisodeDTO {
        let result: EpisodeDTO = try await TraktAPIClient.shared.request(
            uri: "/shows/\(showId)/seasons/\(seasonNumber)/episodes/\(episodeNumber)",
            params: ["extended": "full"]
        )
        return result
    }

    static func translations(id: Int, language: String = "zh") async throws -> [ShowTranslationDTO] {
        try await TraktAPIClient.shared.request(uri: "/shows/\(id)/translations/\(language)")
    }

    static func seasonTranslations(showId: Int, seasonNumber: Int, language: String = "zh") async throws -> [SeasonTranslationDTO] {
        try await TraktAPIClient.shared.request(uri: "/shows/\(showId)/seasons/\(seasonNumber)/translations/\(language)")
    }

    static func episodeTranslations(showId: Int, seasonNumber: Int, episodeNumber: Int, language: String = "zh") async throws -> [EpisodeTranslationDTO] {
        try await TraktAPIClient.shared.request(uri: "/shows/\(showId)/seasons/\(seasonNumber)/episodes/\(episodeNumber)/translations/\(language)")
    }
}
