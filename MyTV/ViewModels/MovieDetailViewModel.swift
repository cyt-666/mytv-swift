import Foundation

@Observable
@MainActor
final class MovieDetailViewModel {
    let movieId: Int
    let commentStore: CommentInteractionStore
    var movie: MovieDetailsDTO?
    var translation: TranslationResult?
    var isLoading = false

    init(movieId: Int) {
        self.movieId = movieId
        self.commentStore = CommentInteractionStore { page, limit in
            try await CommentAPI.movieComments(id: movieId, page: page, limit: limit)
        }
    }

    var isLoggedIn: Bool { AuthService.shared.isLoggedIn }

    func load() async {
        isLoading = true
        defer { isLoading = false }

        do {
            movie = try await MovieAPI.details(id: movieId)
        } catch {
            print("加载电影详情失败: \(error)")
        }

        translation = await TranslationService.shared.getMovieTranslation(id: movieId)
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

        commentStore.isPostingComment = true
        commentStore.commentErrorMessage = nil
        defer { commentStore.isPostingComment = false }

        do {
            let newComment = try await CommentAPI.postMovieComment(
                movieId: movieId,
                comment: text,
                spoiler: commentStore.commentHasSpoiler
            )
            commentStore.commentDraft = ""
            commentStore.commentHasSpoiler = false
            commentStore.insertRootComment(newComment)
        } catch {
            commentStore.commentErrorMessage = CommentAPI.message(for: error)
            print("发布电影评论失败: \(error)")
        }
    }
}
