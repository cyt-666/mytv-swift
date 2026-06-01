import Foundation

@Observable
@MainActor
final class MovieDetailViewModel {
    let movieId: Int
    var movie: MovieDetailsDTO?
    var translation: TranslationResult?
    var comments: [CommentDTO] = []
    var commentDraft = ""
    var commentHasSpoiler = false
    var isLoadingComments = false
    var isPostingComment = false
    var commentErrorMessage: String?
    var isLoading = false

    init(movieId: Int) { self.movieId = movieId }

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
        await loadComments()
    }

    func loadComments() async {
        isLoadingComments = true
        commentErrorMessage = nil
        defer { isLoadingComments = false }

        do {
            comments = try await CommentAPI.movieComments(id: movieId)
        } catch {
            commentErrorMessage = CommentAPI.message(for: error)
            print("加载电影评论失败: \(error)")
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

        isPostingComment = true
        commentErrorMessage = nil
        defer { isPostingComment = false }

        do {
            let newComment = try await CommentAPI.postMovieComment(
                movieId: movieId,
                comment: text,
                spoiler: commentHasSpoiler
            )
            commentDraft = ""
            commentHasSpoiler = false
            comments.insert(newComment, at: 0)
        } catch {
            commentErrorMessage = CommentAPI.message(for: error)
            print("发布电影评论失败: \(error)")
        }
    }
}
