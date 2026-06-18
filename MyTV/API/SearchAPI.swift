import Foundation

@MainActor enum SearchAPI {
    static func search(query: String, page: Int = 1, limit: Int = 15) async throws -> [SearchResultDTO] {
        var params: [String: String] = [
            "query": query,
            "extended": "full,images"
        ]
        params.merge(TraktEndpoint.makePagination(page: page, limit: limit)) { $1 }

        return try await TraktAPIClient.shared.request(uri: "/search/movie,show", params: params)
    }

    static func lookupTMDB(id: Int, mediaKind: MoviePilotMediaKind?) async throws -> [SearchResultDTO] {
        var params: [String: String] = [
            "extended": "full,images"
        ]

        switch mediaKind {
        case .movie:
            params["type"] = "movie"
        case .tv:
            params["type"] = "show"
        case .none:
            params["type"] = "movie,show"
        }

        return try await TraktAPIClient.shared.request(uri: "/search/tmdb/\(id)", params: params)
    }
}
