import Foundation
import SwiftUI

@Observable
@MainActor
final class ShowDetailViewModel {
    let showId: Int
    let commentStore: CommentInteractionStore
    var show: ShowDetailsDTO?
    var seasons: [SeasonDTO] = []
    var translation: TranslationResult?
    var isLoading = false
    var isMarkingWatched = false
    var isLoadingWatchedStatus = false
    var isWatched = false
    var watchedMessage: String?
    var watchedErrorMessage: String?

    @ObservationIgnored
    private var appState: AppState?

    init(showId: Int) {
        self.showId = showId
        self.commentStore = CommentInteractionStore { page, limit in
            try await CommentAPI.showComments(id: showId, page: page, limit: limit)
        }
    }

    func configure(appState: AppState) { self.appState = appState }

    var isLoggedIn: Bool { AuthService.shared.isLoggedIn }

    func load() async {
        isLoading = true
        defer { isLoading = false }

        do {
            async let showResult = ShowAPI.details(id: showId)
            async let seasonsResult = ShowAPI.seasons(id: showId)
            show = try await showResult
            seasons = try await seasonsResult
        } catch {
            print("加载剧集详情失败: \(error)")
        }

        await refreshWatchedStatus()
        translation = await TranslationService.shared.getShowTranslation(id: showId)
        await commentStore.loadComments()
    }

    func refreshWatchedStatus() async {
        guard isLoggedIn else {
            isWatched = false
            return
        }

        isLoadingWatchedStatus = true
        defer { isLoadingWatchedStatus = false }

        do {
            isWatched = try await UserAPI.hasWatchedShow(id: showId)
        } catch {
            print("同步剧集已看状态失败: \(error)")
        }
    }

    func navigateToSeason(_ seasonNumber: Int) {
        appState?.navigate(to: .seasonDetail(showId: showId, seasonNumber: seasonNumber))
    }

    func postComment() async {
        let text = commentStore.commentDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            commentStore.commentErrorMessage = "先写一条评论"
            return
        }
        guard isLoggedIn else {
            commentStore.commentErrorMessage = "登录 Trakt 后才能发布评论"
            return
        }

        commentStore.isPostingComment = true
        commentStore.commentErrorMessage = nil
        defer { commentStore.isPostingComment = false }

        do {
            let newComment = try await CommentAPI.postShowComment(
                showId: showId,
                comment: text,
                spoiler: commentStore.commentHasSpoiler
            )
            commentStore.commentDraft = ""
            commentStore.commentHasSpoiler = false
            commentStore.insertRootComment(newComment)
        } catch {
            commentStore.commentErrorMessage = CommentAPI.message(for: error)
            print("发布剧集评论失败: \(error)")
        }
    }

    @discardableResult
    func markWatched(at date: Date) async -> Bool {
        guard isLoggedIn else {
            watchedErrorMessage = L10n.string("登录 Trakt 后才能标记已看")
            return false
        }

        guard let show else {
            watchedErrorMessage = L10n.string("条目信息还在加载")
            return false
        }

        guard !isMarkingWatched else { return false }
        isMarkingWatched = true
        watchedMessage = nil
        watchedErrorMessage = nil
        defer { isMarkingWatched = false }

        do {
            _ = try await SyncAPI.addToHistory(shows: [show.ids.trakt], watchedAt: date)
            CacheService.invalidateWatchedData()
            isWatched = true
            watchedMessage = L10n.string("%@已标记为已看", translation?.title ?? show.title)
            return true
        } catch {
            watchedErrorMessage = Self.message(for: error)
            print("标记剧集已看失败: \(error)")
            return false
        }
    }

    private static func message(for error: Error) -> String {
        if let apiError = error as? APIError {
            switch apiError {
            case .unauthorized, .refreshTokenFailed:
                return L10n.string("登录状态已过期，请重新登录 Trakt")
            case .httpError(let statusCode, _):
                switch statusCode {
                case 401: return L10n.string("登录 Trakt 后才能标记已看")
                default: return L10n.string("Trakt 返回错误 %d", statusCode)
                }
            default:
                return apiError.localizedDescription
            }
        }
        return error.localizedDescription
    }
}
