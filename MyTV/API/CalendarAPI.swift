import Foundation

@MainActor enum CalendarAPI {
    static func myShows(startDate: String, days: Int = 7) async throws -> [CalendarShowDTO] {
        let cacheKey = "calendar_my_shows_\(startDate)_\(days)"
        if let cached: [CalendarShowDTO] = CacheService.getAPIResponse(key: cacheKey) {
            return cached
        }
        let result: [CalendarShowDTO] = try await TraktAPIClient.shared.request(
            uri: "/calendars/my/shows/\(startDate)/\(days)",
            params: ["extended": "full,images"],
            requiresAuth: true
        )
        CacheService.setAPIResponse(key: cacheKey, data: result, ttl: AppConstants.CacheTTL.short)
        return result
    }

    static func allShows(startDate: String, days: Int = 7) async throws -> [CalendarShowDTO] {
        let cacheKey = "calendar_all_shows_\(startDate)_\(days)"
        if let cached: [CalendarShowDTO] = CacheService.getAPIResponse(key: cacheKey) {
            return cached
        }
        let result: [CalendarShowDTO] = try await TraktAPIClient.shared.request(
            uri: "/calendars/all/shows/\(startDate)/\(days)",
            params: ["extended": "full,images"]
        )
        CacheService.setAPIResponse(key: cacheKey, data: result, ttl: AppConstants.CacheTTL.short)
        return result
    }

    static func movies(startDate: String, days: Int = 7) async throws -> [CalendarMovieDTO] {
        let cacheKey = "calendar_movies_\(startDate)_\(days)"
        if let cached: [CalendarMovieDTO] = CacheService.getAPIResponse(key: cacheKey) {
            return cached
        }
        let result: [CalendarMovieDTO] = try await TraktAPIClient.shared.request(
            uri: "/calendars/all/movies/\(startDate)/\(days)",
            params: ["extended": "full,images"]
        )
        CacheService.setAPIResponse(key: cacheKey, data: result, ttl: AppConstants.CacheTTL.short)
        return result
    }

    static func newShows(startDate: String, days: Int = 7) async throws -> [CalendarShowDTO] {
        try await TraktAPIClient.shared.request(
            uri: "/calendars/all/shows/new/\(startDate)/\(days)",
            params: ["extended": "full"]
        )
    }

    static func seasonPremieres(startDate: String, days: Int = 7) async throws -> [CalendarShowDTO] {
        try await TraktAPIClient.shared.request(
            uri: "/calendars/all/shows/premieres/\(startDate)/\(days)",
            params: ["extended": "full"]
        )
    }
}
