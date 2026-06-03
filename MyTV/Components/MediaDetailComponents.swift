import SwiftUI

struct DetailMetaChip: View {
    let text: String
    var icon: String?
    var tint: Color = .secondary

    var body: some View {
        HStack(spacing: 5) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
            }
            Text(text)
                .font(.system(size: 12, weight: .semibold))
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.thinMaterial)
        .clipShape(Capsule())
        .overlay {
            Capsule()
                .stroke(.primary.opacity(0.08), lineWidth: 1)
        }
    }
}

struct DetailHeroArtworkView: View {
    let urlString: String?
    let height: CGFloat
    var dimming: Double

    var body: some View {
        ZStack {
            AsyncPosterImage(urlString: urlString)
                .frame(maxWidth: .infinity)
                .frame(height: height)
                .saturation(0.92)
                .brightness(-0.05)
                .clipped()

            Color.black.opacity(dimming)

            LinearGradient(
                colors: [
                    .black.opacity(0.34),
                    .black.opacity(0.10),
                    .black.opacity(0.78)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            LinearGradient(
                colors: [
                    .black.opacity(0.86),
                    .black.opacity(0.32),
                    .black.opacity(0.08),
                    .black.opacity(0.20)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )

            VStack {
                Spacer()
                LinearGradient(
                    colors: [
                        .clear,
                        Color(nsColor: .windowBackgroundColor).opacity(0.34)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 74)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .clipped()
    }
}

struct DetailSectionCard<Content: View>: View {
    let title: String
    private let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(.system(size: 18, weight: .bold))

            content
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(.primary.opacity(0.07), lineWidth: 1)
        }
    }
}

struct DetailInfoRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 70, alignment: .leading)

            Text(value)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.primary)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct DetailStatTile: View {
    let title: String
    let value: String
    var icon: String?
    var tint: Color = .accentColor

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(tint)
            }

            Text(value)
                .font(.system(size: 24, weight: .bold))
                .lineLimit(1)

            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 108, alignment: .leading)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(.primary.opacity(0.07), lineWidth: 1)
        }
    }
}

struct DetailGenreCloud: View {
    let genres: [String]

    var body: some View {
        FlowLayout(spacing: 8) {
            ForEach(genres, id: \.self) { genre in
                Text(genre)
                    .font(.system(size: 12, weight: .semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.quaternary.opacity(0.65))
                    .clipShape(Capsule())
            }
        }
    }
}

struct DetailCommentsSection: View {
    let store: CommentInteractionStore
    let isLoggedIn: Bool
    let onSubmit: () -> Void

    var body: some View {
        DetailSectionCard(title: "评论") {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("来自 Trakt")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)

                    Spacer()

                    Button {
                        Task { await store.loadComments() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .symbolEffect(.rotate, isActive: store.isLoadingComments)
                    }
                    .buttonStyle(.borderless)
                    .disabled(store.isLoadingComments)
                    .help("刷新评论")
                }

                commentComposer

                if let errorMessage = store.commentErrorMessage {
                    Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.orange)
                }

                Divider().opacity(0.45)

                if store.isLoadingComments && store.comments.isEmpty {
                    ProgressView()
                        .controlSize(.small)
                        .frame(maxWidth: .infinity, minHeight: 80)
                } else if store.comments.isEmpty {
                    ContentUnavailableView(
                        "暂无评论",
                        systemImage: "bubble.left",
                        description: Text("这里会显示 Trakt 用户的公开评论")
                    )
                    .frame(maxWidth: .infinity, minHeight: 120)
                } else {
                    VStack(spacing: 12) {
                        ForEach(store.comments) { comment in
                            DetailCommentThreadView(
                                comment: comment,
                                store: store,
                                isLoggedIn: isLoggedIn
                            )
                        }

                        if store.canLoadMoreComments || store.isLoadingComments {
                            Button {
                                Task { await store.loadMoreComments() }
                            } label: {
                                if store.isLoadingComments {
                                    ProgressView()
                                        .controlSize(.small)
                                } else {
                                    Text("加载更多")
                                }
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .disabled(store.isLoadingComments || !store.canLoadMoreComments)
                            .padding(.top, 4)
                        }
                    }
                }
            }
        }
    }

    private var commentComposer: some View {
        VStack(alignment: .leading, spacing: 10) {
            TextEditor(text: Binding(
                get: { store.commentDraft },
                set: { store.commentDraft = $0 }
            ))
                .font(.system(size: 13))
                .frame(minHeight: 86)
                .padding(8)
                .scrollContentBackground(.hidden)
                .background(.quaternary.opacity(0.45))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(.primary.opacity(0.06), lineWidth: 1)
                }
                .overlay(alignment: .topLeading) {
                    if store.commentDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text(isLoggedIn ? "写一条 Trakt 评论..." : "登录 Trakt 后可以发布评论")
                            .font(.system(size: 13))
                            .foregroundStyle(.tertiary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 16)
                        .allowsHitTesting(false)
                    }
                }
                .disabled(!isLoggedIn || store.isPostingComment)

            HStack(spacing: 12) {
                Toggle("包含剧透", isOn: Binding(
                    get: { store.commentHasSpoiler },
                    set: { store.commentHasSpoiler = $0 }
                ))
                    .toggleStyle(.checkbox)
                    .disabled(!isLoggedIn || store.isPostingComment)

                Text("Trakt 通常要求评论至少 5 个词，200 词以上会作为 review。")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)

                Spacer()

                Button {
                    onSubmit()
                } label: {
                    if store.isPostingComment {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Text("发布")
                    }
                }
                .disabled(!canSubmit)
            }
        }
    }

    private var canSubmit: Bool {
        isLoggedIn && !store.isPostingComment && !store.commentDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

private struct DetailCommentThreadView: View {
    let comment: CommentDTO
    let store: CommentInteractionStore
    let isLoggedIn: Bool

    @State private var showsReplies = false
    @State private var showsReplyComposer = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            DetailCommentRow(
                comment: comment,
                likeCount: store.displayLikeCount(for: comment),
                replyCount: store.displayReplyCount(for: comment)
            )

            HStack(spacing: 10) {
                Button {
                    Task { await store.toggleLike(for: comment) }
                } label: {
                    Label(
                        store.isLiked(comment) ? "已赞" : "赞",
                        systemImage: store.isLiked(comment) ? "hand.thumbsup.fill" : "hand.thumbsup"
                    )
                }
                .disabled(!isLoggedIn || store.isLiking(comment))

                if store.displayReplyCount(for: comment) > 0 {
                    Button {
                        showsReplies.toggle()
                        if showsReplies && store.repliesByCommentId[comment.id] == nil {
                            Task { await store.loadReplies(for: comment) }
                        }
                    } label: {
                        Label(showsReplies ? "隐藏回复" : "查看回复", systemImage: "bubble.left.and.bubble.right")
                    }
                }

                Button {
                    showsReplyComposer.toggle()
                } label: {
                    Label("回复", systemImage: "arrowshape.turn.up.left")
                }
                .disabled(!isLoggedIn)
            }
            .font(.system(size: 12, weight: .semibold))
            .buttonStyle(.borderless)
            .controlSize(.small)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 2)

            if showsReplyComposer {
                replyComposer
            }

            if showsReplies {
                repliesView
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.32))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var replyComposer: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextEditor(text: Binding(
                get: { store.replyDrafts[comment.id] ?? "" },
                set: { store.replyDrafts[comment.id] = $0 }
            ))
            .font(.system(size: 13))
            .frame(minHeight: 64)
            .padding(8)
            .scrollContentBackground(.hidden)
            .background(.quaternary.opacity(0.35))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(alignment: .topLeading) {
                if (store.replyDrafts[comment.id] ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text("回复 \(comment.displayName)...")
                        .font(.system(size: 13))
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 16)
                        .allowsHitTesting(false)
                }
            }

            HStack {
                Toggle("包含剧透", isOn: Binding(
                    get: { store.replySpoilers.contains(comment.id) },
                    set: { value in
                        if value {
                            store.replySpoilers.insert(comment.id)
                        } else {
                            store.replySpoilers.remove(comment.id)
                        }
                    }
                ))
                .toggleStyle(.checkbox)

                Spacer()

                Button("取消") {
                    showsReplyComposer = false
                }
                .buttonStyle(.borderless)

                Button {
                    Task {
                        let posted = await store.postReply(to: comment)
                        if posted {
                            showsReplyComposer = false
                            showsReplies = true
                        }
                    }
                } label: {
                    if store.isPostingReply(to: comment) {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Text("回复")
                    }
                }
                .disabled(replyText.isEmpty || store.isPostingReply(to: comment))
            }
            .font(.system(size: 12, weight: .medium))
        }
        .padding(12)
        .background(.primary.opacity(0.035))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var repliesView: some View {
        VStack(alignment: .leading, spacing: 10) {
            if store.isLoadingReplies(for: comment) && (store.repliesByCommentId[comment.id] ?? []).isEmpty {
                ProgressView()
                    .controlSize(.small)
                    .frame(maxWidth: .infinity, minHeight: 44)
            } else {
                ForEach(store.repliesByCommentId[comment.id] ?? []) { reply in
                    DetailCommentRow(
                        comment: reply,
                        likeCount: store.displayLikeCount(for: reply),
                        replyCount: store.displayReplyCount(for: reply)
                    )
                    .padding(.leading, 14)
                }

                if store.canLoadMoreReplies(for: comment) {
                    Button {
                        Task { await store.loadMoreReplies(for: comment) }
                    } label: {
                        if store.isLoadingReplies(for: comment) {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Text("加载更多回复")
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(store.isLoadingReplies(for: comment))
                    .padding(.leading, 14)
                }
            }
        }
    }

    private var replyText: String {
        (store.replyDrafts[comment.id] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private struct DetailCommentRow: View {
    let comment: CommentDTO
    let likeCount: Int
    let replyCount: Int
    @State private var revealsSpoiler = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(comment.displayName)
                    .font(.system(size: 13, weight: .bold))

                if let date = comment.displayDate {
                    Text(date)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.tertiary)
                }

                Spacer()

                HStack(spacing: 8) {
                    if comment.review == true {
                        Label("Review", systemImage: "text.bubble.fill")
                    }
                    if likeCount > 0 {
                        Label("\(likeCount)", systemImage: "hand.thumbsup.fill")
                    }
                    if replyCount > 0 {
                        Label("\(replyCount)", systemImage: "arrowshape.turn.up.left.fill")
                    }
                }
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
            }

            if comment.spoiler == true && !revealsSpoiler {
                HStack(spacing: 10) {
                    Label("这条评论包含剧透", systemImage: "eye.slash.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)

                    Button("显示") {
                        revealsSpoiler = true
                    }
                    .controlSize(.small)
                }
            } else {
                Text(comment.comment ?? "")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
