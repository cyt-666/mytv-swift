import Foundation

@Observable
@MainActor
final class EpisodeDetailViewModel {
    let showId: Int
    let seasonNumber: Int
    let episodeNumber: Int
    var show: ShowDetailsDTO?
    var showTranslation: TranslationResult?
    var episode: EpisodeDTO?
    var translation: TranslationResult?
    var comments: [CommentDTO] = []
    var commentDraft = ""
    var commentHasSpoiler = false
    var isLoadingComments = false
    var isPostingComment = false
    var commentErrorMessage: String?
    var isLoading = false

    init(showId: Int, seasonNumber: Int, episodeNumber: Int) {
        self.showId = showId
        self.seasonNumber = seasonNumber
        self.episodeNumber = episodeNumber
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
        await loadComments()
    }

    func loadComments() async {
        isLoadingComments = true
        commentErrorMessage = nil
        defer { isLoadingComments = false }

        do {
            comments = try await CommentAPI.episodeComments(
                showId: showId,
                seasonNumber: seasonNumber,
                episodeNumber: episodeNumber
            )
        } catch {
            commentErrorMessage = CommentAPI.message(for: error)
            print("加载单集评论失败: \(error)")
        }
    }

    func postComment() async {
        let text = commentDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            commentErrorMessage = "先写一条评论"
            return
        }
        guard isLoggedIn else {
            commentErrorMessage = "登录 Trakt 后才能发布评论"
            return
        }
        guard let episodeId = episode?.ids.trakt else {
            commentErrorMessage = "单集信息还没有加载完成"
            return
        }

        isPostingComment = true
        commentErrorMessage = nil
        defer { isPostingComment = false }

        do {
            let newComment = try await CommentAPI.postEpisodeComment(
                episodeId: episodeId,
                comment: text,
                spoiler: commentHasSpoiler
            )
            commentDraft = ""
            commentHasSpoiler = false
            comments.insert(newComment, at: 0)
        } catch {
            commentErrorMessage = CommentAPI.message(for: error)
            print("发布单集评论失败: \(error)")
        }
    }
}
