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
    let comments: [CommentDTO]
    let isLoading: Bool
    let isPosting: Bool
    let errorMessage: String?
    let isLoggedIn: Bool
    @Binding var draft: String
    @Binding var spoiler: Bool
    let onSubmit: () -> Void
    let onRefresh: () -> Void

    var body: some View {
        DetailSectionCard(title: "评论") {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("来自 Trakt")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)

                    Spacer()

                    Button {
                        onRefresh()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .symbolEffect(.rotate, isActive: isLoading)
                    }
                    .buttonStyle(.borderless)
                    .disabled(isLoading)
                    .help("刷新评论")
                }

                commentComposer

                if let errorMessage {
                    Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.orange)
                }

                Divider().opacity(0.45)

                if isLoading && comments.isEmpty {
                    ProgressView()
                        .controlSize(.small)
                        .frame(maxWidth: .infinity, minHeight: 80)
                } else if comments.isEmpty {
                    ContentUnavailableView(
                        "暂无评论",
                        systemImage: "bubble.left",
                        description: Text("这里会显示 Trakt 用户的公开评论")
                    )
                    .frame(maxWidth: .infinity, minHeight: 120)
                } else {
                    VStack(spacing: 12) {
                        ForEach(Array(comments.prefix(10))) { comment in
                            DetailCommentRow(comment: comment)
                        }
                    }
                }
            }
        }
    }

    private var commentComposer: some View {
        VStack(alignment: .leading, spacing: 10) {
            TextEditor(text: $draft)
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
                    if draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text(isLoggedIn ? "写一条 Trakt 评论..." : "登录 Trakt 后可以发布评论")
                            .font(.system(size: 13))
                            .foregroundStyle(.tertiary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 16)
                            .allowsHitTesting(false)
                    }
                }
                .disabled(!isLoggedIn || isPosting)

            HStack(spacing: 12) {
                Toggle("包含剧透", isOn: $spoiler)
                    .toggleStyle(.checkbox)
                    .disabled(!isLoggedIn || isPosting)

                Text("Trakt 通常要求评论至少 5 个词，200 词以上会作为 review。")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)

                Spacer()

                Button {
                    onSubmit()
                } label: {
                    if isPosting {
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
        isLoggedIn && !isPosting && !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

private struct DetailCommentRow: View {
    let comment: CommentDTO
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
                    if let likes = comment.likes, likes > 0 {
                        Label("\(likes)", systemImage: "hand.thumbsup.fill")
                    }
                    if let replies = comment.replies, replies > 0 {
                        Label("\(replies)", systemImage: "arrowshape.turn.up.left.fill")
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
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.32))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}
