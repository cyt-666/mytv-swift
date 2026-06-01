import Foundation

enum ProgressAPI {
    private static let cacheKey = "up_next_items"
    private static let cacheTTL: TimeInterval = 5 * 60  // 5 minutes

    static func upNext() async throws -> [UpNextItemDTO] {
        if let cached: [UpNextItemDTO] = await CacheService.getAPIResponse(key: cacheKey) {
            Task { _ = try? await fetchAndCache() }
            return cached
        }
        return try await fetchAndCache()
    }

    private static func fetchAndCache() async throws -> [UpNextItemDTO] {
        // Step 1: Get all watched shows (single request)
        let watched: [WatchedShowDTO] = try await TraktAPIClient.shared.request(
            uri: "/users/me/watched/shows",
            params: ["extended": "full,images"],
            requiresAuth: true
        )

        let shows = Array(watched.prefix(60))

        // Step 2: Fetch progress in parallel (non-isolated for true concurrency)
        let items = try await fetchProgressParallel(shows: shows)

        await CacheService.setAPIResponse(key: cacheKey, data: items, ttl: cacheTTL)
        return items
    }

    /// Non-isolated so TaskGroup children run on the thread pool in parallel
    private static func fetchProgressParallel(shows: [WatchedShowDTO]) async throws -> [UpNextItemDTO] {
        try await withThrowingTaskGroup(of: UpNextItemDTO?.self, returning: [UpNextItemDTO].self) { group in
            for watched in shows {
                group.addTask {
                    let progress: ShowProgressDTO = try await TraktAPIClient.shared.request(
                        uri: "/shows/\(watched.show.ids.trakt)/progress/watched",
                        params: ["extended": "full"],
                        requiresAuth: true
                    )
                    guard let nextEp = progress.nextEpisode else { return nil }
                    return UpNextItemDTO(
                        show: watched.show,
                        nextEpisode: nextEp,
                        progress: ShowProgressSummaryDTO(
                            aired: progress.aired,
                            completed: progress.completed,
                            inferredCompleted: inferredCompletedCount(progress: progress, watched: watched),
                            lastWatchedAt: progress.lastWatchedAt
                        )
                    )
                }
            }

            var results: [UpNextItemDTO] = []
            for try await item in group {
                if let item { results.append(item) }
            }
            return results.sorted { ($0.progress.lastWatchedAt ?? "") > ($1.progress.lastWatchedAt ?? "") }
        }
    }

    private static func inferredCompletedCount(progress: ShowProgressDTO, watched: WatchedShowDTO) -> Int {
        var candidates = [progress.completed]

        if let watchedCount = watchedEpisodeCount(from: watched, resetAt: progress.resetAt) {
            candidates.append(watchedCount)
        }

        if let lastEpisode = progress.lastEpisode {
            if lastEpisode.season == progress.nextEpisode?.season || lastEpisode.season == 1 {
                candidates.append(lastEpisode.number)
            }
        }

        if let nextEpisode = progress.nextEpisode, nextEpisode.season == 1 {
            candidates.append(max(nextEpisode.number - 1, 0))
        }

        return candidates.max() ?? progress.completed
    }

    private static func watchedEpisodeCount(from watched: WatchedShowDTO, resetAt: String?) -> Int? {
        guard let seasons = watched.seasons else { return nil }

        let resetDate = resetAt.flatMap(parseTraktDate)
        var count = 0

        for season in seasons where season.number > 0 {
            for episode in season.episodes ?? [] where (episode.plays ?? 0) > 0 {
                if let resetDate {
                    guard
                        let watchedAtString = episode.lastWatchedAt,
                        let watchedAt = parseTraktDate(watchedAtString),
                        watchedAt >= resetDate
                    else {
                        continue
                    }
                }

                count += 1
            }
        }

        return count
    }

    private static func parseTraktDate(_ value: String) -> Date? {
        let fractionalParser = ISO8601DateFormatter()
        fractionalParser.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractionalParser.date(from: value) {
            return date
        }

        let parser = ISO8601DateFormatter()
        parser.formatOptions = [.withInternetDateTime]
        return parser.date(from: value)
    }
}

// MARK: - DTOs for /users/me/watched/shows

struct WatchedShowDTO: Codable {
    let plays: Int?
    let lastWatchedAt: String?
    let seasons: [WatchedSeasonDTO]?
    let show: ShowDTO

    enum CodingKeys: String, CodingKey {
        case plays
        case lastWatchedAt = "last_watched_at"
        case seasons
        case show
    }
}

struct WatchedSeasonDTO: Codable {
    let number: Int
    let episodes: [WatchedEpisodeDTO]?
}

struct WatchedEpisodeDTO: Codable {
    let number: Int
    let plays: Int?
    let lastWatchedAt: String?

    enum CodingKeys: String, CodingKey {
        case number, plays
        case lastWatchedAt = "last_watched_at"
    }
}

struct WatchlistShowDTO: Codable, Identifiable {
    let listedAt: String
    let show: ShowDTO

    var id: Int { show.ids.trakt }

    enum CodingKeys: String, CodingKey {
        case listedAt = "listed_at"
        case show
    }
}
