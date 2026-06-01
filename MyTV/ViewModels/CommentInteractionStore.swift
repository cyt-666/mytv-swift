import Foundation

typealias CommentPageLoader = (_ page: Int, _ limit: Int) async throws -> [CommentDTO]

@Observable
@MainActor
final class CommentInteractionStore {
    var comments: [CommentDTO] = []
    var commentDraft = ""
    var commentHasSpoiler = false
    var isLoadingComments = false
    var isPostingComment = false
    var canLoadMoreComments = false
    var commentErrorMessage: String?

    var repliesByCommentId: [Int: [CommentDTO]] = [:]
    var replyDrafts: [Int: String] = [:]
    var replySpoilers: Set<Int> = []
    var loadingReplyIds: Set<Int> = []
    var postingReplyIds: Set<Int> = []
    var canLoadMoreRepliesByCommentId: [Int: Bool] = [:]

    var likedCommentIds: Set<Int> = []
    var likingCommentIds: Set<Int> = []
    var likeCountDeltas: [Int: Int] = [:]
    var replyCountDeltas: [Int: Int] = [:]

    private let commentPageLimit = 20
    private let replyPageLimit = 10
    private var commentsPage = 0
    private var replyPagesByCommentId: [Int: Int] = [:]
    private let loadPage: CommentPageLoader

    init(loadPage: @escaping CommentPageLoader) {
        self.loadPage = loadPage
    }

    func loadComments() async {
        guard !isLoadingComments else { return }
        isLoadingComments = true
        commentErrorMessage = nil
        defer { isLoadingComments = false }

        do {
            let pageItems = try await loadPage(1, commentPageLimit)
            comments = pageItems
            commentsPage = 1
            canLoadMoreComments = pageItems.count == commentPageLimit
        } catch {
            commentErrorMessage = CommentAPI.message(for: error)
            print("加载评论失败: \(error)")
        }
    }

    func loadMoreComments() async {
        guard !isLoadingComments, canLoadMoreComments else { return }
        isLoadingComments = true
        commentErrorMessage = nil
        defer { isLoadingComments = false }

        do {
            let nextPage = commentsPage + 1
            let pageItems = try await loadPage(nextPage, commentPageLimit)
            appendUnique(pageItems, to: &comments)
            commentsPage = nextPage
            canLoadMoreComments = pageItems.count == commentPageLimit
        } catch {
            commentErrorMessage = CommentAPI.message(for: error)
            print("加载更多评论失败: \(error)")
        }
    }

    func insertRootComment(_ comment: CommentDTO) {
        comments.insert(comment, at: 0)
    }

    func displayLikeCount(for comment: CommentDTO) -> Int {
        max(0, (comment.likes ?? 0) + (likeCountDeltas[comment.id] ?? 0))
    }

    func displayReplyCount(for comment: CommentDTO) -> Int {
        max(0, (comment.replies ?? 0) + (replyCountDeltas[comment.id] ?? 0))
    }

    func isLiked(_ comment: CommentDTO) -> Bool {
        likedCommentIds.contains(comment.id)
    }

    func isLiking(_ comment: CommentDTO) -> Bool {
        likingCommentIds.contains(comment.id)
    }

    func isLoadingReplies(for comment: CommentDTO) -> Bool {
        loadingReplyIds.contains(comment.id)
    }

    func isPostingReply(to comment: CommentDTO) -> Bool {
        postingReplyIds.contains(comment.id)
    }

    func canLoadMoreReplies(for comment: CommentDTO) -> Bool {
        canLoadMoreRepliesByCommentId[comment.id] ?? false
    }

    func toggleLike(for comment: CommentDTO) async {
        guard AuthService.shared.isLoggedIn else {
            commentErrorMessage = "登录 Trakt 后才能点赞"
            return
        }
        guard !likingCommentIds.contains(comment.id) else { return }

        let wasLiked = likedCommentIds.contains(comment.id)
        likingCommentIds.insert(comment.id)
        commentErrorMessage = nil
        defer { likingCommentIds.remove(comment.id) }

        do {
            if wasLiked {
                try await CommentAPI.unlikeComment(id: comment.id)
                likedCommentIds.remove(comment.id)
                likeCountDeltas[comment.id, default: 0] -= 1
            } else {
                try await CommentAPI.likeComment(id: comment.id)
                likedCommentIds.insert(comment.id)
                likeCountDeltas[comment.id, default: 0] += 1
            }
        } catch APIError.httpError(let statusCode, _) where statusCode == 409 && !wasLiked {
            likedCommentIds.insert(comment.id)
        } catch {
            commentErrorMessage = CommentAPI.message(for: error)
            print("切换评论点赞失败: \(error)")
        }
    }

    func loadReplies(for comment: CommentDTO) async {
        guard !loadingReplyIds.contains(comment.id) else { return }
        loadingReplyIds.insert(comment.id)
        commentErrorMessage = nil
        defer { loadingReplyIds.remove(comment.id) }

        do {
            let pageItems = try await CommentAPI.commentReplies(id: comment.id, page: 1, limit: replyPageLimit)
            repliesByCommentId[comment.id] = pageItems
            replyPagesByCommentId[comment.id] = 1
            updateReplyPagination(for: comment, latestPageCount: pageItems.count)
        } catch {
            commentErrorMessage = CommentAPI.message(for: error)
            print("加载评论回复失败: \(error)")
        }
    }

    func loadMoreReplies(for comment: CommentDTO) async {
        guard canLoadMoreReplies(for: comment), !loadingReplyIds.contains(comment.id) else { return }
        loadingReplyIds.insert(comment.id)
        commentErrorMessage = nil
        defer { loadingReplyIds.remove(comment.id) }

        do {
            let nextPage = (replyPagesByCommentId[comment.id] ?? 1) + 1
            let pageItems = try await CommentAPI.commentReplies(id: comment.id, page: nextPage, limit: replyPageLimit)
            var replies = repliesByCommentId[comment.id] ?? []
            appendUnique(pageItems, to: &replies)
            repliesByCommentId[comment.id] = replies
            replyPagesByCommentId[comment.id] = nextPage
            updateReplyPagination(for: comment, latestPageCount: pageItems.count)
        } catch {
            commentErrorMessage = CommentAPI.message(for: error)
            print("加载更多评论回复失败: \(error)")
        }
    }

    func postReply(to comment: CommentDTO) async -> Bool {
        let text = (replyDrafts[comment.id] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            commentErrorMessage = "先写一条回复"
            return false
        }
        guard AuthService.shared.isLoggedIn else {
            commentErrorMessage = "登录 Trakt 后才能回复"
            return false
        }
        guard !postingReplyIds.contains(comment.id) else { return false }

        postingReplyIds.insert(comment.id)
        commentErrorMessage = nil
        defer { postingReplyIds.remove(comment.id) }

        do {
            let newReply = try await CommentAPI.postReply(
                commentId: comment.id,
                comment: text,
                spoiler: replySpoilers.contains(comment.id)
            )
            var replies = repliesByCommentId[comment.id] ?? []
            replies.insert(newReply, at: 0)
            repliesByCommentId[comment.id] = replies
            replyCountDeltas[comment.id, default: 0] += 1
            replyDrafts[comment.id] = ""
            replySpoilers.remove(comment.id)
            updateReplyPagination(for: comment, latestPageCount: replies.count)
            return true
        } catch {
            commentErrorMessage = CommentAPI.message(for: error)
            print("发布评论回复失败: \(error)")
            return false
        }
    }

    private func updateReplyPagination(for comment: CommentDTO, latestPageCount: Int) {
        let loadedCount = repliesByCommentId[comment.id]?.count ?? 0
        let knownTotal = displayReplyCount(for: comment)
        let canLoadKnownTotal = knownTotal > loadedCount
        let canLoadUnknownTotal = comment.replies == nil && latestPageCount == replyPageLimit
        canLoadMoreRepliesByCommentId[comment.id] = canLoadKnownTotal || canLoadUnknownTotal
    }

    private func appendUnique(_ pageItems: [CommentDTO], to target: inout [CommentDTO]) {
        let existingIds = Set(target.map(\.id))
        target.append(contentsOf: pageItems.filter { !existingIds.contains($0.id) })
    }
}
