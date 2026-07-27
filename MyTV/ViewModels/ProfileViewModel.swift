import Foundation

@Observable
@MainActor
final class ProfileViewModel {
    var user: UserDTO?
    var stats: UserStatsDTO?
    var currentMonthStats: MonthlyWatchStats?
    var previousMonthStats: MonthlyWatchStats?
    var activities: [ProfileActivityItem] = []
    var isLoading = false
    var isLoadingActivities = false
    var errorMessage: String?
    var activityErrorMessage: String?

    func load() async {
        guard AuthService.shared.isLoggedIn else { return }

        user = AuthService.shared.userProfile?.user ?? user
        isLoading = true
        isLoadingActivities = true
        errorMessage = nil
        activityErrorMessage = nil

        async let profileResult = UserAPI.profile()
        async let statsResult = UserAPI.stats()
        async let currentMonthResult = MonthlyWatchStatsService.load(for: Date())
        async let previousMonthResult = MonthlyWatchStatsService.load(
            for: MonthlyWatchStatsService.previousMonthDate()
        )
        async let activitiesResult = loadActivities()

        do {
            let profile = try await profileResult
            user = profile.user
        } catch {
            print("加载用户资料失败: \(error)")
            if user == nil {
                errorMessage = "用户资料加载失败"
            }
        }

        do {
            stats = try await statsResult
        } catch {
            print("加载用户统计失败: \(error)")
            errorMessage = errorMessage ?? "统计数据加载失败"
        }

        do {
            currentMonthStats = try await currentMonthResult
        } catch {
            print("加载本月统计失败: \(error)")
            currentMonthStats = currentMonthStats ?? MonthlyWatchStats.empty(for: Date())
        }

        do {
            previousMonthStats = try await previousMonthResult
        } catch {
            print("加载上月统计失败: \(error)")
            let previousDate = MonthlyWatchStatsService.previousMonthDate()
            previousMonthStats = previousMonthStats ?? MonthlyWatchStats.empty(for: previousDate)
        }

        do {
            activities = try await activitiesResult
        } catch {
            print("加载个人动态失败: \(error)")
            activityErrorMessage = "动态加载失败"
        }

        isLoading = false
        isLoadingActivities = false
    }

    private func loadActivities() async throws -> [ProfileActivityItem] {
        async let commentsResult = UserAPI.comments(limit: 8)
        async let movieRatingsResult = UserAPI.ratings(type: "movies", limit: 6)
        async let showRatingsResult = UserAPI.ratings(type: "shows", limit: 6)
        async let episodeRatingsResult = UserAPI.ratings(type: "episodes", limit: 6)

        var items: [ProfileActivityItem] = []
        var loadErrors: [Error] = []

        do {
            items.append(contentsOf: try await commentsResult.map(makeCommentActivity))
        } catch {
            loadErrors.append(error)
        }

        do {
            items.append(contentsOf: try await movieRatingsResult.map(makeRatingActivity))
        } catch {
            loadErrors.append(error)
        }

        do {
            items.append(contentsOf: try await showRatingsResult.map(makeRatingActivity))
        } catch {
            loadErrors.append(error)
        }

        do {
            items.append(contentsOf: try await episodeRatingsResult.map(makeRatingActivity))
        } catch {
            loadErrors.append(error)
        }

        let sortedItems = items
            .sorted { lhs, rhs in
                (lhs.date ?? .distantPast) > (rhs.date ?? .distantPast)
            }
            .prefix(12)

        if sortedItems.isEmpty, let firstError = loadErrors.first {
            throw firstError
        }

        return Array(sortedItems)
    }

    private func makeCommentActivity(from item: UserCommentItemDTO) -> ProfileActivityItem {
        let media = mediaInfo(
            type: item.type,
            movie: item.movie,
            show: item.show,
            season: item.season,
            episode: item.episode
        )
        let comment = item.comment
        let dateValue = comment.createdAt ?? comment.updatedAt
        let date = dateValue.flatMap(MonthlyWatchStatsService.parseTraktDate)
        let isReview = comment.review == true
        let commentText: String

        if comment.spoiler == true {
            commentText = L10n.string("含剧透内容")
        } else {
            commentText = Self.cleanedText(comment.comment) ?? (isReview ? L10n.string("发表了一篇影评") : L10n.string("发表了一条评论"))
        }

        return ProfileActivityItem(
            id: "comment_\(comment.id)",
            kind: isReview ? .review : .comment,
            title: media.title,
            subtitle: media.subtitle,
            date: date,
            dateText: Self.formatActivityDate(dateValue),
            posterURL: media.posterURL,
            body: commentText,
            rating: comment.userRating ?? comment.userStats?.rating,
            route: media.route
        )
    }

    private func makeRatingActivity(from item: UserRatingItemDTO) -> ProfileActivityItem {
        let media = mediaInfo(
            type: item.type ?? item.mediaType,
            movie: item.movie,
            show: item.show,
            season: item.season,
            episode: item.episode
        )

        return ProfileActivityItem(
            id: "rating_\(item.id)",
            kind: .rating,
            title: media.title,
            subtitle: media.subtitle,
            date: MonthlyWatchStatsService.parseTraktDate(item.ratedAt),
            dateText: Self.formatActivityDate(item.ratedAt),
            posterURL: media.posterURL,
            body: nil,
            rating: item.rating,
            route: media.route
        )
    }

    private func mediaInfo(
        type: String?,
        movie: MovieDTO?,
        show: ShowDTO?,
        season: SeasonDTO?,
        episode: EpisodeDTO?
    ) -> ProfileActivityMediaInfo {
        if let movie {
            return ProfileActivityMediaInfo(
                title: movie.title,
                subtitle: movie.year.map { L10n.string("电影 · %@", "\($0)") } ?? L10n.string("电影"),
                posterURL: movie.images?.poster?.first,
                route: .movieDetail(id: movie.ids.trakt)
            )
        }

        if let episode {
            let title = show?.title ?? episode.title ?? L10n.string("未知剧集")
            let episodeTitle = episode.title.map { " · \($0)" } ?? ""
            let route: Route?
            if let show {
                route = .episodeDetail(
                    showId: show.ids.trakt,
                    seasonNumber: episode.season,
                    episodeNumber: episode.number
                )
            } else {
                route = nil
            }

            return ProfileActivityMediaInfo(
                title: title,
                subtitle: "S\(episode.season)E\(episode.number)\(episodeTitle)",
                posterURL: show?.images?.poster?.first ?? episode.images?.poster?.first,
                route: route
            )
        }

        if let season {
            let title = show?.title ?? season.title ?? L10n.string("未知剧集")
            let route: Route?
            if let show {
                route = .seasonDetail(showId: show.ids.trakt, seasonNumber: season.number)
            } else {
                route = nil
            }

            return ProfileActivityMediaInfo(
                title: title,
                subtitle: L10n.string("第 %d 季", season.number),
                posterURL: show?.images?.poster?.first ?? season.images?.poster?.first,
                route: route
            )
        }

        if let show {
            return ProfileActivityMediaInfo(
                title: show.title,
                subtitle: show.year.map { L10n.string("剧集 · %@", "\($0)") } ?? L10n.string("剧集"),
                posterURL: show.images?.poster?.first,
                route: .showDetail(id: show.ids.trakt)
            )
        }

        return ProfileActivityMediaInfo(
            title: L10n.string("未知内容"),
            subtitle: type ?? L10n.string("动态"),
            posterURL: nil,
            route: nil
        )
    }

    private static func cleanedText(_ text: String?) -> String? {
        guard let text else { return nil }
        let cleaned = text
            .replacingOccurrences(of: "\n", with: " ")
            .split(separator: " ")
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? nil : cleaned
    }

    private static func formatActivityDate(_ value: String?) -> String {
        guard let value,
              let date = MonthlyWatchStatsService.parseTraktDate(value) else {
            return value.map { String($0.prefix(10)) } ?? L10n.string("未知时间")
        }

        let formatter = DateFormatter()
        formatter.locale = L10n.locale
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

private struct ProfileActivityMediaInfo {
    let title: String
    let subtitle: String
    let posterURL: String?
    let route: Route?
}

struct ProfileActivityItem: Identifiable, Hashable {
    enum Kind: Hashable {
        case comment
        case review
        case rating

        var title: String {
            switch self {
            case .comment: return L10n.string("评论")
            case .review: return L10n.string("影评")
            case .rating: return L10n.string("评分")
            }
        }

        var icon: String {
            switch self {
            case .comment: return "text.bubble.fill"
            case .review: return "quote.bubble.fill"
            case .rating: return "star.fill"
            }
        }
    }

    let id: String
    let kind: Kind
    let title: String
    let subtitle: String
    let date: Date?
    let dateText: String
    let posterURL: String?
    let body: String?
    let rating: Int?
    let route: Route?
}
