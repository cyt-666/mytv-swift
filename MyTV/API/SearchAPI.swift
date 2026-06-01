import Foundation

@MainActor enum SearchAPI {
    static func search(query: String, page: Int = 1, limit: Int = 15) async throws -> [SearchResultDTO] {
        var params: [String: String] = ["query": query]
        params.merge(TraktEndpoint.makePagination(page: page, limit: limit)) { $1 }

        return try await TraktAPIClient.shared.request(uri: "/search/movie,show", params: params)
    }
}
