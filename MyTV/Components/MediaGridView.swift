import SwiftUI

struct MediaGridView: View {
    let items: [MediaItem]
    var onItemTap: ((MediaItem) -> Void)?
    var onItemAppear: ((MediaItem) -> Void)?
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var isCompact: Bool {
        AdaptiveLayout.isCompact(horizontalSizeClass)
    }

    private var cardWidth: CGFloat {
        isCompact ? 96 : 150
    }

    private var columns: [GridItem] {
        [
            GridItem(
                .adaptive(minimum: isCompact ? 94 : 140, maximum: isCompact ? 108 : 180),
                spacing: isCompact ? 12 : 16,
                alignment: .top
            )
        ]
    }

    var body: some View {
        LazyVGrid(columns: columns, spacing: isCompact ? 14 : 20) {
            ForEach(items) { item in
                MediaCardView(item: item, posterWidth: cardWidth)
                    .onAppear {
                        onItemAppear?(item)
                    }
            }
        }
    }
}

struct PaginationFooterView: View {
    let isLoadingMore: Bool
    let canLoadMore: Bool
    let errorMessage: String?
    let onRetry: () -> Void

    var body: some View {
        Group {
            if let errorMessage {
                VStack(spacing: 10) {
                    Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.orange)
                        .lineLimit(3)
                        .multilineTextAlignment(.center)

                    Button("重试", action: onRetry)
                        .controlSize(.small)
                }
            } else if isLoadingMore {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text("正在加载更多...")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            } else if canLoadMore {
                ProgressView()
                    .controlSize(.small)
                    .opacity(0)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
    }
}
