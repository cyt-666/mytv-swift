import Foundation

@MainActor enum SyncAPI {
    static func addToCollection(movies: [Int]? = nil, shows: [Int]? = nil) async throws -> SyncDTO {
        var body: [String: Any] = [:]
        if let movies {
            body["movies"] = movies.map { ["ids": ["trakt": $0]] }
        }
        if let shows {
            body["shows"] = shows.map { ["ids": ["trakt": $0]] }
        }
        return try await TraktAPIClient.shared.request(method: "POST", uri: "/sync/collection", body: body, requiresAuth: true)
    }

    static func removeFromCollection(movies: [Int]? = nil, shows: [Int]? = nil) async throws -> SyncDTO {
        var body: [String: Any] = [:]
        if let movies {
            body["movies"] = movies.map { ["ids": ["trakt": $0]] }
        }
        if let shows {
            body["shows"] = shows.map { ["ids": ["trakt": $0]] }
        }
        return try await TraktAPIClient.shared.request(method: "POST", uri: "/sync/collection/remove", body: body, requiresAuth: true)
    }

    static func addToWatchlist(movies: [Int]? = nil, shows: [Int]? = nil) async throws -> SyncDTO {
        var body: [String: Any] = [:]
        if let movies {
            body["movies"] = movies.map { ["ids": ["trakt": $0]] }
        }
        if let shows {
            body["shows"] = shows.map { ["ids": ["trakt": $0]] }
        }
        return try await TraktAPIClient.shared.request(method: "POST", uri: "/sync/watchlist", body: body, requiresAuth: true)
    }

    static func removeFromWatchlist(movies: [Int]? = nil, shows: [Int]? = nil) async throws -> SyncDTO {
        var body: [String: Any] = [:]
        if let movies {
            body["movies"] = movies.map { ["ids": ["trakt": $0]] }
        }
        if let shows {
            body["shows"] = shows.map { ["ids": ["trakt": $0]] }
        }
        return try await TraktAPIClient.shared.request(method: "POST", uri: "/sync/watchlist/remove", body: body, requiresAuth: true)
    }

    static func addToHistory(movies: [Int]? = nil, shows: [Int]? = nil, episodes: [[String: Int]]? = nil) async throws -> SyncDTO {
        var body: [String: Any] = [:]
        if let movies {
            body["movies"] = movies.map { ["ids": ["trakt": $0]] }
        }
        if let shows {
            body["shows"] = shows.map { ["ids": ["trakt": $0]] }
        }
        if let episodes {
            body["episodes"] = episodes.map { ["ids": $0] }
        }
        return try await TraktAPIClient.shared.request(method: "POST", uri: "/sync/history", body: body, requiresAuth: true)
    }
}
