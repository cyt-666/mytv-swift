import Foundation

@Observable
@MainActor
final class HomeViewModel {
    var monthlyStats: MonthlyWatchStats?
    var recommendedMovies: [MovieDTO] = []
    var recommendedShows: [ShowDTO] = []
    var upNextItems: [UpNextItemDTO] = []
    var startWatchingShows: [ShowDTO] = []
    var isLoading = false

    var shouldShowRailPlaceholders: Bool {
        AuthService.shared.isLoggedIn && isLoading
    }

    func load() async {
        if AuthService.shared.isLoggedIn {
            restoreCachedContentIfNeeded()
        }

        isLoading = true
        defer { isLoading = false }

        if AuthService.shared.isLoggedIn {
            // Load all user-specific data in parallel
            async let stats = MonthlyWatchStatsService.load(for: Date())
            async let recMovies = RecommendationAPI.movies()
            async let recShows = RecommendationAPI.shows()
            async let upNext = ProgressAPI.upNext()
            async let startShows = loadStartWatching()
            var didLoadRailContent = false

            do {
                let freshStats = try await stats
                monthlyStats = freshStats
                Self.cacheMonthlyStats(freshStats)
            } catch {
                print("加载本月观影统计失败: \(error)")
                if monthlyStats == nil {
                    monthlyStats = Self.cachedMonthlyStats() ?? MonthlyWatchStats.empty(for: Date())
                }
            }
            do {
                recommendedMovies = Array((try await recMovies).prefix(10))
                didLoadRailContent = true
            } catch {
                print("加载推荐电影失败: \(error)")
            }
            do {
                recommendedShows = Array((try await recShows).prefix(10))
                didLoadRailContent = true
            } catch {
                print("加载推荐剧集失败: \(error)")
            }
            do {
                upNextItems = Array((try await upNext).prefix(10))
                didLoadRailContent = true
            } catch {
                print("加载继续观看失败: \(error)")
            }
            do {
                startWatchingShows = Array((try await startShows).prefix(10))
                didLoadRailContent = true
            } catch {
                print("加载开始观看失败: \(error)")
            }

            if didLoadRailContent {
                cacheHomeContent()
            }
        } else {
            monthlyStats = nil
            recommendedMovies = []
            recommendedShows = []
            upNextItems = []
            startWatchingShows = []
        }
    }

    /// Watchlist ∩ Collection = shows the user owns and wants to watch
    private func loadStartWatching() async throws -> [ShowDTO] {
        async let watchlistResult: [WatchlistShowDTO] = TraktAPIClient.shared.request(
            uri: "/users/me/watchlist/shows",
            params: ["extended": "full,images"],
            requiresAuth: true
        )
        async let collectionResult: [CollectionShowDTO] = TraktAPIClient.shared.request(
            uri: "/users/me/collection/shows",
            params: ["extended": "full,images"],
            requiresAuth: true
        )

        let watchlist = try await watchlistResult
        let collection = try await collectionResult

        let collectionIds = Set(collection.map(\.show.ids.trakt))
        return watchlist
            .filter { collectionIds.contains($0.show.ids.trakt) }
            .map(\.show)
    }

    private func restoreCachedContentIfNeeded() {
        if monthlyStats == nil {
            monthlyStats = Self.cachedMonthlyStats()
        }

        guard let cached = Self.cachedHomeContent() else { return }

        if recommendedMovies.isEmpty {
            recommendedMovies = Array(cached.recommendedMovies.prefix(10))
        }
        if recommendedShows.isEmpty {
            recommendedShows = Array(cached.recommendedShows.prefix(10))
        }
        if upNextItems.isEmpty {
            upNextItems = Array(cached.upNextItems.prefix(10))
        }
        if startWatchingShows.isEmpty {
            startWatchingShows = Array(cached.startWatchingShows.prefix(10))
        }
    }

    private func cacheHomeContent() {
        let snapshot = HomeContentSnapshot(
            recommendedMovies: recommendedMovies,
            recommendedShows: recommendedShows,
            upNextItems: upNextItems,
            startWatchingShows: startWatchingShows
        )
        Self.cacheHomeContent(snapshot)
    }

    private static func cachedMonthlyStats() -> MonthlyWatchStats? {
        CacheService.getUserData(key: monthlyStatsCacheKey)?.data
    }

    private static func cacheMonthlyStats(_ stats: MonthlyWatchStats) {
        CacheService.setUserData(key: monthlyStatsCacheKey, data: stats)
    }

    private static func cachedHomeContent() -> HomeContentSnapshot? {
        CacheService.getUserData(key: homeContentCacheKey)?.data
    }

    private static func cacheHomeContent(_ snapshot: HomeContentSnapshot) {
        CacheService.setUserData(key: homeContentCacheKey, data: snapshot)
    }

    private static let homeContentCacheKey = "home_content_snapshot"

    private static var monthlyStatsCacheKey: String {
        let components = Calendar.current.dateComponents([.year, .month], from: Date())
        let year = components.year ?? 0
        let month = components.month ?? 0
        return "home_monthly_stats_\(year)-\(month)"
    }
}

private struct HomeContentSnapshot: Codable {
    let recommendedMovies: [MovieDTO]
    let recommendedShows: [ShowDTO]
    let upNextItems: [UpNextItemDTO]
    let startWatchingShows: [ShowDTO]
}

@MainActor
enum MonthlyWatchStatsService {
    static func load(for date: Date) async throws -> MonthlyWatchStats {
        let calendar = Calendar.current
        let monthStart = startOfMonth(containing: date, calendar: calendar)
        let nextMonthStart = calendar.date(byAdding: .month, value: 1, to: monthStart) ?? date

        let startAt = traktDateFormatter.string(from: monthStart)
        let endAt = traktDateFormatter.string(from: nextMonthStart)

        var allItems: [HistoryItemDTO] = []
        let limit = 100
        for page in 1...5 {
            let pageItems = try await UserAPI.history(page: page, limit: limit, startAt: startAt, endAt: endAt)
            allItems.append(contentsOf: pageItems)
            if pageItems.count < limit {
                break
            }
        }

        return makeStats(from: allItems, monthStart: monthStart)
    }

    static func previousMonthDate(from date: Date = Date()) -> Date {
        Calendar.current.date(byAdding: .month, value: -1, to: date) ?? date
    }

    private static func makeStats(from items: [HistoryItemDTO], monthStart: Date) -> MonthlyWatchStats {
        let calendar = Calendar.current
        var watchedDays = Set<Date>()
        var dayCounts: [Date: Int] = [:]
        var estimatedMinutes = 0

        for item in items {
            if let watchedDate = parseTraktDate(item.watchedAt) {
                let day = calendar.startOfDay(for: watchedDate)
                watchedDays.insert(day)
                dayCounts[day, default: 0] += 1
            }
            estimatedMinutes += runtimeMinutes(for: item)
        }

        let busiestDay = dayCounts
            .sorted { lhs, rhs in
                if lhs.value == rhs.value {
                    return lhs.key > rhs.key
                }
                return lhs.value > rhs.value
            }
            .first

        let sortedItems = items
            .sorted { lhs, rhs in
                (parseTraktDate(lhs.watchedAt) ?? .distantPast) > (parseTraktDate(rhs.watchedAt) ?? .distantPast)
            }

        return MonthlyWatchStats(
            monthTitle: monthFormatter.string(from: monthStart),
            totalCount: items.count,
            movieCount: items.filter { $0.type == "movie" }.count,
            episodeCount: items.filter { $0.type == "episode" }.count,
            watchedDays: watchedDays.count,
            estimatedMinutes: estimatedMinutes,
            busiestDay: busiestDay.map { dayFormatter.string(from: $0.key) },
            busiestDayCount: busiestDay?.value ?? 0,
            recentItems: sortedItems.prefix(3).map(makeRecentWatchItem),
            backgroundURL: sortedItems.lazy.compactMap(backgroundURL).first
        )
    }

    private static func startOfMonth(containing date: Date, calendar: Calendar) -> Date {
        let components = calendar.dateComponents([.year, .month], from: date)
        return calendar.date(from: components) ?? date
    }

    private static func runtimeMinutes(for item: HistoryItemDTO) -> Int {
        switch item.type {
        case "movie":
            return item.movie?.runtime ?? 0
        case "episode":
            return item.episode?.runtime ?? item.show?.runtime ?? 0
        default:
            return item.movie?.runtime ?? item.episode?.runtime ?? item.show?.runtime ?? 0
        }
    }

    private static func makeRecentWatchItem(from item: HistoryItemDTO) -> MonthlyRecentWatchItem {
        let title: String
        let subtitle: String
        let posterURL: String?

        if item.type == "movie" {
            title = item.movie?.title ?? "未知电影"
            subtitle = "电影"
            posterURL = item.movie?.images?.poster?.first
        } else if item.type == "episode" {
            title = item.show?.title ?? item.episode?.title ?? "未知剧集"
            if let episode = item.episode {
                let episodeTitle = episode.title.map { " · \($0)" } ?? ""
                subtitle = "S\(episode.season)E\(episode.number)\(episodeTitle)"
            } else {
                subtitle = "剧集"
            }
            posterURL = item.show?.images?.poster?.first ?? item.episode?.images?.poster?.first
        } else {
            title = item.movie?.title ?? item.show?.title ?? item.episode?.title ?? "未知"
            subtitle = item.type
            posterURL = item.movie?.images?.poster?.first ?? item.show?.images?.poster?.first ?? item.episode?.images?.poster?.first
        }

        return MonthlyRecentWatchItem(
            id: item.id,
            title: title,
            subtitle: subtitle,
            watchedAt: item.watchedAt,
            posterURL: posterURL
        )
    }

    private static func backgroundURL(for item: HistoryItemDTO) -> String? {
        switch item.type {
        case "movie":
            let images = item.movie?.images
            if let url = images?.fanart?.first { return url }
            if let url = images?.banner?.first { return url }
            if let url = images?.poster?.first { return url }
            return nil
        case "episode":
            let showImages = item.show?.images
            let episodeImages = item.episode?.images
            if let url = showImages?.fanart?.first { return url }
            if let url = episodeImages?.fanart?.first { return url }
            if let url = episodeImages?.screenshot?.first { return url }
            if let url = showImages?.banner?.first { return url }
            if let url = showImages?.poster?.first { return url }
            return nil
        default:
            let movieImages = item.movie?.images
            let showImages = item.show?.images
            let episodeImages = item.episode?.images

            if let url = movieImages?.fanart?.first { return url }
            if let url = showImages?.fanart?.first { return url }
            if let url = episodeImages?.fanart?.first { return url }
            if let url = episodeImages?.screenshot?.first { return url }
            if let url = movieImages?.poster?.first { return url }
            if let url = showImages?.poster?.first { return url }
            return nil
        }
    }

    static func parseTraktDate(_ value: String) -> Date? {
        traktDateParserWithFractionalSeconds.date(from: value) ?? traktDateParser.date(from: value)
    }

    private static let traktDateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    private static let traktDateParserWithFractionalSeconds: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let traktDateParser: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    private static let monthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy年M月"
        return formatter
    }()

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M月d日"
        return formatter
    }()
}

struct MonthlyWatchStats: Codable {
    let monthTitle: String
    let totalCount: Int
    let movieCount: Int
    let episodeCount: Int
    let watchedDays: Int
    let estimatedMinutes: Int
    let busiestDay: String?
    let busiestDayCount: Int
    let recentItems: [MonthlyRecentWatchItem]
    let backgroundURL: String?

    var estimatedHoursText: String {
        guard estimatedMinutes > 0 else { return "暂无" }
        let hours = Double(estimatedMinutes) / 60
        if hours < 1 {
            return "\(estimatedMinutes) 分钟"
        }
        return String(format: "%.1f 小时", hours)
    }

    static func empty(for date: Date) -> MonthlyWatchStats {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy年M月"
        return MonthlyWatchStats(
            monthTitle: formatter.string(from: date),
            totalCount: 0,
            movieCount: 0,
            episodeCount: 0,
            watchedDays: 0,
            estimatedMinutes: 0,
            busiestDay: nil,
            busiestDayCount: 0,
            recentItems: [],
            backgroundURL: nil
        )
    }
}

struct MonthlyRecentWatchItem: Identifiable, Codable {
    let id: Int
    let title: String
    let subtitle: String
    let watchedAt: String
    let posterURL: String?
}
