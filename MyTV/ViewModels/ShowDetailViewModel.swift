import Foundation
import SwiftUI

@Observable
@MainActor
final class ShowDetailViewModel {
    let showId: Int
    var show: ShowDetailsDTO?
    var seasons: [SeasonDTO] = []
    var translation: TranslationResult?
    var comments: [CommentDTO] = []
    var commentDraft = ""
    var commentHasSpoiler = false
    var isLoadingComments = false
    var isPostingComment = false
    var commentErrorMessage: String?
    var isLoading = false

    @ObservationIgnored
    private var appState: AppState?

    init(showId: Int) { self.showId = showId }

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

        translation = await TranslationService.shared.getShowTranslation(id: showId)
        await loadComments()
    }

    func navigateToSeason(_ seasonNumber: Int) {
        appState?.navigate(to: .seasonDetail(showId: showId, seasonNumber: seasonNumber))
    }

    func loadComments() async {
        isLoadingComments = true
        commentErrorMessage = nil
        defer { isLoadingComments = false }

        do {
            comments = try await CommentAPI.showComments(id: showId)
        } catch {
            commentErrorMessage = CommentAPI.message(for: error)
            print("加载剧集评论失败: \(error)")
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
            let newComment = try await CommentAPI.postShowComment(
                showId: showId,
                comment: text,
                spoiler: commentHasSpoiler
            )
            commentDraft = ""
            commentHasSpoiler = false
            comments.insert(newComment, at: 0)
        } catch {
            commentErrorMessage = CommentAPI.message(for: error)
            print("发布剧集评论失败: \(error)")
        }
    }
}
