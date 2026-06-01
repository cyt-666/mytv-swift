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

        async let episodeTranslation = TranslationService.shared.getEpisodeTranslation(
            showId: showId, seasonNumber: seasonNumber, episodeNumber: episodeNumber
        )
        async let seriesTranslation = TranslationService.shared.getShowTranslation(id: showId)
        translation = await episodeTranslation
        showTranslation = await seriesTranslation
        await commentStore.loadComments()
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
}
