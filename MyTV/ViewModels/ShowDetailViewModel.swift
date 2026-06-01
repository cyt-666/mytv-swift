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

        translation = await TranslationService.shared.getShowTranslation(id: showId)
        await commentStore.loadComments()
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
}
