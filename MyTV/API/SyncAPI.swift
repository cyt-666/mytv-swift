import Foundation

@MainActor enum SyncAPI {
    static func addToCollection(movies: [Int]? = nil, shows: [Int]? = nil) async throws -> SyncDTO {
        let body = SyncBody(
            movies: movies?.map { SyncItem(traktID: $0) },
            shows: shows?.map { SyncItem(traktID: $0) }
        )
        return try await TraktAPIClient.shared.request(
            method: "POST",
            uri: "/sync/collection",
            bodyData: try encode(body),
            requiresAuth: true
        )
    }

    static func removeFromCollection(movies: [Int]? = nil, shows: [Int]? = nil) async throws -> SyncDTO {
        let body = SyncBody(
            movies: movies?.map { SyncItem(traktID: $0) },
            shows: shows?.map { SyncItem(traktID: $0) }
        )
        return try await TraktAPIClient.shared.request(
            method: "POST",
            uri: "/sync/collection/remove",
            bodyData: try encode(body),
            requiresAuth: true
        )
    }

    static func addToWatchlist(
        movies: [Int]? = nil,
        shows: [Int]? = nil,
        seasons: [Int]? = nil,
        episodes: [Int]? = nil
    ) async throws -> SyncDTO {
        let body = SyncBody(
            movies: movies?.map { SyncItem(traktID: $0) },
            shows: shows?.map { SyncItem(traktID: $0) },
            seasons: seasons?.map { SyncItem(traktID: $0) },
            episodes: episodes?.map { SyncItem(traktID: $0) }
        )
        return try await TraktAPIClient.shared.request(
            method: "POST",
            uri: "/sync/watchlist",
            bodyData: try encode(body),
            requiresAuth: true
        )
    }

    static func removeFromWatchlist(
        movies: [Int]? = nil,
        shows: [Int]? = nil,
        seasons: [Int]? = nil,
        episodes: [Int]? = nil
    ) async throws -> SyncDTO {
        let body = SyncBody(
            movies: movies?.map { SyncItem(traktID: $0) },
            shows: shows?.map { SyncItem(traktID: $0) },
            seasons: seasons?.map { SyncItem(traktID: $0) },
            episodes: episodes?.map { SyncItem(traktID: $0) }
        )
        return try await TraktAPIClient.shared.request(
            method: "POST",
            uri: "/sync/watchlist/remove",
            bodyData: try encode(body),
            requiresAuth: true
        )
    }

    static func addToHistory(
        movies: [Int]? = nil,
        shows: [Int]? = nil,
        episodes: [[String: Int]]? = nil,
        watchedAt: Date? = nil
    ) async throws -> SyncDTO {
        let watchedAtString = watchedAt.map(Self.traktDateFormatter.string(from:))
        let body = SyncBody(
            movies: movies?.map { SyncItem(traktID: $0, watchedAt: watchedAtString) },
            shows: shows?.map { SyncItem(traktID: $0, watchedAt: watchedAtString) },
            episodes: episodes?.map { SyncItem(ids: $0, watchedAt: watchedAtString) }
        )
        return try await TraktAPIClient.shared.request(
            method: "POST",
            uri: "/sync/history",
            bodyData: try encode(body),
            requiresAuth: true
        )
    }

    private static func encode(_ body: SyncBody) throws -> Data {
        try JSONEncoder().encode(body)
    }

    private struct SyncBody: Encodable, Sendable {
        var movies: [SyncItem]?
        var shows: [SyncItem]?
        var seasons: [SyncItem]?
        var episodes: [SyncItem]?

        init(
            movies: [SyncItem]? = nil,
            shows: [SyncItem]? = nil,
            seasons: [SyncItem]? = nil,
            episodes: [SyncItem]? = nil
        ) {
            self.movies = movies
            self.shows = shows
            self.seasons = seasons
            self.episodes = episodes
        }
    }

    private struct SyncItem: Encodable, Sendable {
        var ids: [String: Int]
        var watchedAt: String?

        enum CodingKeys: String, CodingKey {
            case ids
            case watchedAt = "watched_at"
        }

        init(traktID: Int, watchedAt: String? = nil) {
            self.ids = ["trakt": traktID]
            self.watchedAt = watchedAt
        }

        init(ids: [String: Int], watchedAt: String? = nil) {
            self.ids = ids
            self.watchedAt = watchedAt
        }
    }

    private static let traktDateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()
}
