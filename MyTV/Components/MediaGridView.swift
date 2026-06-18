import SwiftUI

struct MediaGridView: View {
    let items: [MediaItem]
    var onItemTap: ((MediaItem) -> Void)?
    var onItemAppear: ((MediaItem) -> Void)?

    private let columns = [
        GridItem(.adaptive(minimum: 140, maximum: 180), spacing: 16)
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 20) {
            ForEach(items) { item in
                MediaCardView(item: item)
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
