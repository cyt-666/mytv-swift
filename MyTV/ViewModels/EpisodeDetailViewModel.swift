import Foundation

@Observable
@MainActor
final class EpisodeDetailViewModel {
    let showId: Int
    let seasonNumber: Int
    let episodeNumber: Int
    let commentStore: CommentInteractionStore
    var show: ShowDetailsDTO?
    var showTranslation: TranslationResult?
    var episode: EpisodeDTO?
    var translation: TranslationResult?
    var isLoading = false
    var isMarkingWatched = false
    var isLoadingWatchedStatus = false
    var isWatched = false
    var watchedAt: Date?
    var watchedMessage: String?
    var watchedErrorMessage: String?

    init(showId: Int, seasonNumber: Int, episodeNumber: Int) {
        self.showId = showId
        self.seasonNumber = seasonNumber
        self.episodeNumber = episodeNumber
        self.commentStore = CommentInteractionStore { page, limit in
            try await CommentAPI.episodeComments(
                showId: showId,
                seasonNumber: seasonNumber,
                episodeNumber: episodeNumber,
                page: page,
                limit: limit
            )
        }
    }

    var isLoggedIn: Bool { AuthService.shared.isLoggedIn }

    func load() async {
        isLoading = true
        defer { isLoading = false }

        do {
            async let episodeResult = ShowAPI.episodeDetails(
                showId: showId,
                seasonNumber: seasonNumber,
                episodeNumber: episodeNumber
            )
            async let showResult = ShowAPI.details(id: showId)
            episode = try await episodeResult
            show = try await showResult
        } catch {
            print("加载剧集详情失败: \(error)")
        }

        await refreshWatchedStatus()
        async let episodeTranslation = TranslationService.shared.getEpisodeTranslation(
            showId: showId, seasonNumber: seasonNumber, episodeNumber: episodeNumber
        )
        async let seriesTranslation = TranslationService.shared.getShowTranslation(id: showId)
        translation = await episodeTranslation
        showTranslation = await seriesTranslation
        await commentStore.loadComments()
    }

    func refreshWatchedStatus() async {
        guard isLoggedIn else {
            isWatched = false
            watchedAt = nil
            return
        }
        guard let episodeId = episode?.ids.trakt else { return }

        isLoadingWatchedStatus = true
        defer { isLoadingWatchedStatus = false }

        do {
            let status = try await UserAPI.watchedStatus(type: "episodes", id: episodeId)
            isWatched = status.isWatched
            watchedAt = DetailWatchedDateFormatter.parse(status.watchedAt)
        } catch {
            print("同步单集已看状态失败: \(error)")
        }
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
        guard let episodeId = episode?.ids.trakt else {
            commentStore.commentErrorMessage = "单集信息还没有加载完成"
            return
        }

        commentStore.isPostingComment = true
        commentStore.commentErrorMessage = nil
        defer { commentStore.isPostingComment = false }

        do {
            let newComment = try await CommentAPI.postEpisodeComment(
                episodeId: episodeId,
                comment: text,
                spoiler: commentStore.commentHasSpoiler
            )
            commentStore.commentDraft = ""
            commentStore.commentHasSpoiler = false
            commentStore.insertRootComment(newComment)
        } catch {
            commentStore.commentErrorMessage = CommentAPI.message(for: error)
            print("发布单集评论失败: \(error)")
        }
    }

    func markWatched(at date: Date) async -> Bool {
        guard isLoggedIn else {
            watchedErrorMessage = L10n.string("登录 Trakt 后才能标记已看")
            return false
        }
        guard let episodeId = episode?.ids.trakt else {
            watchedErrorMessage = L10n.string("单集信息还没有加载完成")
            return false
        }

        isMarkingWatched = true
        watchedMessage = nil
        watchedErrorMessage = nil
        defer { isMarkingWatched = false }

        do {
            _ = try await SyncAPI.addToHistory(
                episodes: [["trakt": episodeId]],
                watchedAt: date
            )
            CacheService.invalidateWatchedData()
            isWatched = true
            watchedAt = date
            watchedMessage = L10n.string("%@已标记为已看", messageTitle)
            return true
        } catch {
            watchedErrorMessage = message(for: error)
            print("标记单集已看失败: \(error)")
            return false
        }
    }

    private var messageTitle: String {
        if let translated = translation?.title, !translated.isEmpty {
            return translated
        }
        if let title = episode?.title, !title.isEmpty {
            return title
        }
        return "S\(seasonNumber)E\(episodeNumber)"
    }

    private func message(for error: Error) -> String {
        if let localizedError = error as? LocalizedError,
           let description = localizedError.errorDescription {
            return description
        }
        return error.localizedDescription
    }
}
