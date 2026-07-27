import Foundation

@MainActor enum UserAPI {
    static func profile() async throws -> UserProfileDTO {
        let cacheKey = "user_profile_me"
        if let cached: (data: UserProfileDTO, isStale: Bool) = CacheService.getUserData(key: cacheKey) {
            if cached.isStale {
                Task { _ = try? await fetchAndCacheProfile(cacheKey: cacheKey) }
            }
            return cached.data
        }
        return try await fetchAndCacheProfile(cacheKey: cacheKey)
    }

    private static func fetchAndCacheProfile(cacheKey: String) async throws -> UserProfileDTO {
        let result: UserProfileDTO = try await TraktAPIClient.shared.request(uri: "/users/settings", requiresAuth: true)
        CacheService.setUserData(key: cacheKey, data: result)
        return result
    }

    static func stats() async throws -> UserStatsDTO {
        let cacheKey = "user_stats_me"
        if let cached: (data: UserStatsDTO, isStale: Bool) = CacheService.getUserData(key: cacheKey) {
            return cached.data
        }
        let result: UserStatsDTO = try await TraktAPIClient.shared.request(uri: "/users/me/stats", requiresAuth: true)
        CacheService.setUserData(key: cacheKey, data: result)
        return result
    }

    static func watched(type: String) async throws -> [MovieWatchedDTO] {
        let cacheKey = "user_watched_\(type)"
        if let cached: [MovieWatchedDTO] = CacheService.getAPIResponse(key: cacheKey) {
            return cached
        }
        let result: [MovieWatchedDTO] = try await TraktAPIClient.shared.request(
            uri: "/users/me/watched/\(type)",
            params: ["extended": "full,images"],
            requiresAuth: true
        )
        CacheService.setAPIResponse(key: cacheKey, data: result)
        return result
    }

    static func collection(type: String) async throws -> [MovieCollectedDTO] {
        let cacheKey = "user_collection_\(type)"
        if let cached: [MovieCollectedDTO] = CacheService.getAPIResponse(key: cacheKey) {
            return cached
        }
        let result: [MovieCollectedDTO] = try await TraktAPIClient.shared.request(
            uri: "/users/me/collection/\(type)",
            params: ["extended": "full,images"],
            requiresAuth: true
        )
        CacheService.setAPIResponse(key: cacheKey, data: result)
        return result
    }

    static func watchlist(type: String) async throws -> [MovieDTO] {
        let cacheKey = "user_watchlist_\(type)"
        if let cached: [MovieDTO] = CacheService.getAPIResponse(key: cacheKey) {
            return cached
        }
        let result: [MovieDTO] = try await TraktAPIClient.shared.request(
            uri: "/users/me/watchlist/\(type)",
            params: ["extended": "full,images"],
            requiresAuth: true
        )
        CacheService.setAPIResponse(key: cacheKey, data: result)
        return result
    }

    static func customLists(username: String) async throws -> [TraktListDTO] {
        let cacheKey = "user_lists_\(username)"
        if let cached: [TraktListDTO] = CacheService.getAPIResponse(key: cacheKey) {
            return cached
        }
        let result: [TraktListDTO] = try await TraktAPIClient.shared.request(
            uri: "/users/\(username)/lists",
            requiresAuth: true
        )
        CacheService.setAPIResponse(key: cacheKey, data: result, ttl: AppConstants.CacheTTL.short)
        return result
    }

    static func history(
        type: String? = nil,
        page: Int = 1,
        limit: Int = 15,
        startAt: String? = nil,
        endAt: String? = nil
    ) async throws -> [HistoryItemDTO] {
        var params: [String: String] = ["extended": "full,images"]
        params.merge(TraktEndpoint.makePagination(page: page, limit: limit)) { $1 }
        if let startAt {
            params["start_at"] = startAt
        }
        if let endAt {
            params["end_at"] = endAt
        }

        let uri = type.map { "/users/me/history/\($0)" } ?? "/users/me/history"
        let cacheKey = [
            "user_history",
            type ?? "all",
            "p\(page)",
            "l\(limit)",
            startAt ?? "start_any",
            endAt ?? "end_any"
        ].joined(separator: "_")
        if let cached: [HistoryItemDTO] = CacheService.getAPIResponse(key: cacheKey) {
            return cached
        }
        let result: [HistoryItemDTO] = try await TraktAPIClient.shared.request(uri: uri, params: params, requiresAuth: true)
        CacheService.setAPIResponse(key: cacheKey, data: result, ttl: AppConstants.CacheTTL.short)
        return result
    }

    static func hasWatched(type: String, id: Int) async throws -> Bool {
        let result: [HistoryItemDTO] = try await TraktAPIClient.shared.request(
            uri: "/users/me/history/\(type)/\(id)",
            params: TraktEndpoint.makePagination(page: 1, limit: 1),
            requiresAuth: true
        )
        return !result.isEmpty
    }

    static func hasWatchedShow(id: Int) async throws -> Bool {
        let progress: ShowProgressDTO = try await TraktAPIClient.shared.request(
            uri: "/shows/\(id)/progress/watched",
            params: ["extended": "full"],
            requiresAuth: true
        )
        return progress.aired > 0 && (progress.completed >= progress.aired || progress.nextEpisode == nil)
    }

    static func comments(
        commentType: String = "all",
        type: String = "all",
        page: Int = 1,
        limit: Int = 12
    ) async throws -> [UserCommentItemDTO] {
        var params: [String: String] = ["extended": "full,images"]
        params.merge(TraktEndpoint.makePagination(page: page, limit: limit)) { $1 }

        let cacheKey = "user_comments_\(commentType)_\(type)_p\(page)_l\(limit)"
        if let cached: [UserCommentItemDTO] = CacheService.getAPIResponse(key: cacheKey) {
            return cached
        }

        let result: [UserCommentItemDTO] = try await TraktAPIClient.shared.request(
            uri: "/users/me/comments/\(commentType)/\(type)",
            params: params,
            requiresAuth: true
        )
        CacheService.setAPIResponse(key: cacheKey, data: result, ttl: AppConstants.CacheTTL.short)
        return result
    }

    static func ratings(
        type: String,
        page: Int = 1,
        limit: Int = 12
    ) async throws -> [UserRatingItemDTO] {
        var params: [String: String] = ["extended": "full,images"]
        params.merge(TraktEndpoint.makePagination(page: page, limit: limit)) { $1 }

        let cacheKey = "user_ratings_\(type)_p\(page)_l\(limit)"
        if let cached: [UserRatingItemDTO] = CacheService.getAPIResponse(key: cacheKey) {
            return cached
        }

        let result: [UserRatingItemDTO] = try await TraktAPIClient.shared.request(
            uri: "/users/me/ratings/\(type)",
            params: params,
            requiresAuth: true
        )
        CacheService.setAPIResponse(key: cacheKey, data: result, ttl: AppConstants.CacheTTL.short)
        return result
    }
}

struct TraktListDTO: Codable, Identifiable, Hashable {
    let name: String
    let description: String?
    let privacy: String?
    let itemCount: Int?
    let ids: TraktListIdsDTO

    var id: Int { ids.trakt }

    enum CodingKeys: String, CodingKey {
        case name, description, privacy, ids
        case itemCount = "item_count"
    }
}

struct TraktListIdsDTO: Codable, Hashable {
    let trakt: Int
    let slug: String?
}

struct HistoryItemDTO: Codable, Identifiable {
    let id: Int
    let watchedAt: String
    let action: String
    let type: String
    let movie: MovieDTO?
    let show: ShowDTO?
    let episode: EpisodeDTO?

    enum CodingKeys: String, CodingKey {
        case id
        case watchedAt = "watched_at"
        case action, type, movie, show, episode
    }
}

struct UserCommentItemDTO: Codable, Identifiable {
    let comment: CommentDTO
    let type: String?
    let movie: MovieDTO?
    let show: ShowDTO?
    let season: SeasonDTO?
    let episode: EpisodeDTO?

    var id: Int { comment.id }
}

struct UserRatingItemDTO: Codable, Identifiable {
    let ratedAt: String
    let rating: Int
    let type: String?
    let movie: MovieDTO?
    let show: ShowDTO?
    let season: SeasonDTO?
    let episode: EpisodeDTO?

    var id: String {
        [
            type ?? mediaType,
            "\(movie?.ids.trakt ?? show?.ids.trakt ?? season?.ids.trakt ?? episode?.ids.trakt ?? 0)",
            ratedAt
        ].joined(separator: "_")
    }

    var mediaType: String {
        if movie != nil { return "movie" }
        if episode != nil { return "episode" }
        if season != nil { return "season" }
        if show != nil { return "show" }
        return "rating"
    }

    enum CodingKeys: String, CodingKey {
        case ratedAt = "rated_at"
        case rating, type, movie, show, season, episode
    }
}

@MainActor enum CommentAPI {
    static func movieComments(id: Int, sort: String = "newest", page: Int = 1, limit: Int = 20) async throws -> [CommentDTO] {
        let cacheKey = "comments_movie_\(id)_\(sort)_p\(page)_l\(limit)"
        if let cached: [CommentDTO] = CacheService.getAPIResponse(key: cacheKey) {
            return cached
        }
        let result: [CommentDTO] = try await TraktAPIClient.shared.request(
            uri: "/movies/\(id)/comments/\(sort)",
            params: TraktEndpoint.makePagination(page: page, limit: limit)
        )
        CacheService.setAPIResponse(key: cacheKey, data: result, ttl: AppConstants.CacheTTL.short)
        return result
    }

    static func showComments(id: Int, sort: String = "newest", page: Int = 1, limit: Int = 20) async throws -> [CommentDTO] {
        let cacheKey = "comments_show_\(id)_\(sort)_p\(page)_l\(limit)"
        if let cached: [CommentDTO] = CacheService.getAPIResponse(key: cacheKey) {
            return cached
        }
        let result: [CommentDTO] = try await TraktAPIClient.shared.request(
            uri: "/shows/\(id)/comments/\(sort)",
            params: TraktEndpoint.makePagination(page: page, limit: limit)
        )
        CacheService.setAPIResponse(key: cacheKey, data: result, ttl: AppConstants.CacheTTL.short)
        return result
    }

    static func episodeComments(
        showId: Int,
        seasonNumber: Int,
        episodeNumber: Int,
        sort: String = "newest",
        page: Int = 1,
        limit: Int = 20
    ) async throws -> [CommentDTO] {
        let cacheKey = "comments_episode_\(showId)_s\(seasonNumber)_e\(episodeNumber)_\(sort)_p\(page)_l\(limit)"
        if let cached: [CommentDTO] = CacheService.getAPIResponse(key: cacheKey) {
            return cached
        }
        let result: [CommentDTO] = try await TraktAPIClient.shared.request(
            uri: "/shows/\(showId)/seasons/\(seasonNumber)/episodes/\(episodeNumber)/comments/\(sort)",
            params: TraktEndpoint.makePagination(page: page, limit: limit)
        )
        CacheService.setAPIResponse(key: cacheKey, data: result, ttl: AppConstants.CacheTTL.short)
        return result
    }

    static func commentReplies(id: Int, page: Int = 1, limit: Int = 10) async throws -> [CommentDTO] {
        let cacheKey = "comments_replies_\(id)_p\(page)_l\(limit)"
        if let cached: [CommentDTO] = CacheService.getAPIResponse(key: cacheKey) {
            return cached
        }
        let result: [CommentDTO] = try await TraktAPIClient.shared.request(
            uri: "/comments/\(id)/replies",
            params: TraktEndpoint.makePagination(page: page, limit: limit)
        )
        CacheService.setAPIResponse(key: cacheKey, data: result, ttl: AppConstants.CacheTTL.short)
        return result
    }

    static func postMovieComment(movieId: Int, comment: String, spoiler: Bool) async throws -> CommentDTO {
        try await TraktAPIClient.shared.request(
            method: "POST",
            uri: "/comments",
            body: [
                "movie": ["ids": ["trakt": movieId]],
                "comment": comment,
                "spoiler": spoiler
            ],
            requiresAuth: true
        )
    }

    static func postShowComment(showId: Int, comment: String, spoiler: Bool) async throws -> CommentDTO {
        try await TraktAPIClient.shared.request(
            method: "POST",
            uri: "/comments",
            body: [
                "show": ["ids": ["trakt": showId]],
                "comment": comment,
                "spoiler": spoiler
            ],
            requiresAuth: true
        )
    }

    static func postEpisodeComment(episodeId: Int, comment: String, spoiler: Bool) async throws -> CommentDTO {
        try await TraktAPIClient.shared.request(
            method: "POST",
            uri: "/comments",
            body: [
                "episode": ["ids": ["trakt": episodeId]],
                "comment": comment,
                "spoiler": spoiler
            ],
            requiresAuth: true
        )
    }

    static func postReply(commentId: Int, comment: String, spoiler: Bool) async throws -> CommentDTO {
        try await TraktAPIClient.shared.request(
            method: "POST",
            uri: "/comments/\(commentId)/replies",
            body: [
                "comment": comment,
                "spoiler": spoiler
            ],
            requiresAuth: true
        )
    }

    static func likeComment(id: Int) async throws {
        let _: EmptyResponse = try await TraktAPIClient.shared.request(
            method: "POST",
            uri: "/comments/\(id)/like",
            requiresAuth: true
        )
    }

    static func unlikeComment(id: Int) async throws {
        let _: EmptyResponse = try await TraktAPIClient.shared.request(
            method: "DELETE",
            uri: "/comments/\(id)/like",
            requiresAuth: true
        )
    }

    static func message(for error: Error) -> String {
        if let apiError = error as? APIError {
            switch apiError {
            case .unauthorized, .refreshTokenFailed:
                return L10n.string("登录状态已过期，请重新登录 Trakt")
            case .httpError(let statusCode, _):
                switch statusCode {
                case 401:
                    return L10n.string("登录 Trakt 后才能发布评论")
                case 409:
                    return L10n.string("Trakt 认为这个操作已经完成过")
                case 422:
                    return L10n.string("Trakt 没有接受这条评论，通常需要至少 5 个词")
                default:
                    return L10n.string("Trakt 评论请求失败: %d", statusCode)
                }
            default:
                return apiError.localizedDescription
            }
        }
        return error.localizedDescription
    }
}

struct CommentDTO: Codable, Identifiable, Hashable {
    let id: Int
    let parentId: Int?
    let createdAt: String?
    let updatedAt: String?
    let comment: String?
    let spoiler: Bool?
    let review: Bool?
    let replies: Int?
    let likes: Int?
    let userRating: Int?
    let userStats: CommentUserStatsDTO?
    let user: CommentUserDTO?

    var displayName: String {
        if let name = user?.name, !name.isEmpty {
            return name
        }
        if let username = user?.username, !username.isEmpty {
            return username
        }
        return L10n.string("Trakt 用户")
    }

    var displayDate: String? {
        guard let value = createdAt ?? updatedAt else { return nil }
        return String(value.prefix(10))
    }

    enum CodingKeys: String, CodingKey {
        case id
        case parentId = "parent_id"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case comment, spoiler, review, replies, likes, user
        case userRating = "user_rating"
        case userStats = "user_stats"
    }
}

struct CommentUserStatsDTO: Codable, Hashable {
    let rating: Int?
    let playCount: Int?
    let completedCount: Int?

    enum CodingKeys: String, CodingKey {
        case rating
        case playCount = "play_count"
        case completedCount = "completed_count"
    }
}

struct CommentUserDTO: Codable, Hashable {
    let username: String?
    let isPrivate: Bool?
    let name: String?
    let isVIP: Bool?
    let isVIPEP: Bool?
    let ids: CommentUserIdsDTO?
    let images: UserImagesDTO?

    enum CodingKeys: String, CodingKey {
        case username, name, ids, images
        case isPrivate = "private"
        case isVIP = "vip"
        case isVIPEP = "vip_ep"
    }
}

struct CommentUserIdsDTO: Codable, Hashable {
    let slug: String?
    let uuid: String?
}
