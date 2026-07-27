import Foundation

@MainActor enum ListAPI {
    static func watchlistItems(type: String) async throws -> [TraktListItemDTO] {
        let cacheKey = "watchlist_items_\(type)"
        if let cached: [TraktListItemDTO] = CacheService.getAPIResponse(key: cacheKey) {
            return cached
        }
        let result: [TraktListItemDTO] = try await TraktAPIClient.shared.request(
            uri: "/users/me/watchlist/\(type)",
            params: ["extended": "full,images"],
            requiresAuth: true
        )
        CacheService.setAPIResponse(key: cacheKey, data: result, ttl: AppConstants.CacheTTL.short)
        return result
    }

    static func createList(
        username: String,
        name: String,
        description: String?,
        privacy: String,
        displayNumbers: Bool,
        allowComments: Bool
    ) async throws -> TraktListDTO {
        var body: [String: Any] = [
            "name": name,
            "privacy": privacy,
            "display_numbers": displayNumbers,
            "allow_comments": allowComments
        ]
        if let description, !description.isEmpty {
            body["description"] = description
        }

        return try await TraktAPIClient.shared.request(
            method: "POST",
            uri: "/users/\(username)/lists",
            body: body,
            requiresAuth: true
        )
    }

    static func items(username: String, listId: Int, type: String) async throws -> [TraktListItemDTO] {
        let cacheKey = "list_items_\(username)_\(listId)_\(type)"
        if let cached: [TraktListItemDTO] = CacheService.getAPIResponse(key: cacheKey) {
            return cached
        }
        let result: [TraktListItemDTO] = try await TraktAPIClient.shared.request(
            uri: "/users/\(username)/lists/\(listId)/items/\(type)",
            params: ["extended": "full,images"],
            requiresAuth: true
        )
        CacheService.setAPIResponse(key: cacheKey, data: result, ttl: AppConstants.CacheTTL.short)
        return result
    }

    static func addToList(username: String, listId: Int, target: MediaListTarget) async throws -> SyncDTO {
        try await TraktAPIClient.shared.request(
            method: "POST",
            uri: "/users/\(username)/lists/\(listId)/items",
            body: target.syncBody,
            requiresAuth: true
        )
    }

    static func removeFromList(username: String, listId: Int, target: MediaListTarget) async throws -> SyncDTO {
        try await TraktAPIClient.shared.request(
            method: "POST",
            uri: "/users/\(username)/lists/\(listId)/items/remove",
            body: target.syncBody,
            requiresAuth: true
        )
    }
}

enum MediaListTarget: Hashable {
    case movie(Int)
    case show(Int)
    case season(Int)
    case episode(Int)

    var watchlistLabel: String {
        switch self {
        case .movie: return L10n.string("将电影加入观看清单")
        case .show: return L10n.string("将剧集加入观看清单")
        case .season: return L10n.string("将本季加入观看清单")
        case .episode: return L10n.string("将本集加入观看清单")
        }
    }

    var successName: String {
        switch self {
        case .movie: return L10n.string("电影")
        case .show: return L10n.string("剧集")
        case .season: return L10n.string("季度")
        case .episode: return L10n.string("单集")
        }
    }

    var itemType: String {
        switch self {
        case .movie: return "movies"
        case .show: return "shows"
        case .season: return "seasons"
        case .episode: return "episodes"
        }
    }

    func matches(_ item: TraktListItemDTO) -> Bool {
        switch self {
        case .movie(let id):
            return item.movie?.ids.trakt == id
        case .show(let id):
            return item.show?.ids.trakt == id
        case .season(let id):
            return item.season?.ids.trakt == id
        case .episode(let id):
            return item.episode?.ids.trakt == id
        }
    }

    var syncBody: [String: Any] {
        switch self {
        case .movie(let id):
            return ["movies": [["ids": ["trakt": id]]]]
        case .show(let id):
            return ["shows": [["ids": ["trakt": id]]]]
        case .season(let id):
            return ["seasons": [["ids": ["trakt": id]]]]
        case .episode(let id):
            return ["episodes": [["ids": ["trakt": id]]]]
        }
    }
}

struct TraktListItemDTO: Codable, Hashable {
    let listedAt: String?
    let type: String?
    let movie: MovieDTO?
    let show: ShowDTO?
    let season: SeasonDTO?
    let episode: EpisodeDTO?

    enum CodingKeys: String, CodingKey {
        case listedAt = "listed_at"
        case type, movie, show, season, episode
    }
}
