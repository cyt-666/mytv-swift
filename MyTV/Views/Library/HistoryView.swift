import SwiftUI

struct HistoryView: View {
    @State private var viewModel = HistoryViewModel()

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                if viewModel.isLoading && viewModel.items.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.top, 100)
                } else if let error = viewModel.errorMessage {
                    ContentUnavailableView {
                        Text(error)
                    } actions: {
                        Button("重试") { Task { CacheService.clearAllAPIResponses(); await viewModel.load() } }
                    }
                    .padding(.top, 100)
                } else if viewModel.items.isEmpty {
                    ContentUnavailableView(
                        "暂无观看历史",
                        systemImage: "clock.arrow.circlepath",
                        description: Text("观看过的电影和剧集会显示在这里")
                    )
                    .padding(.top, 100)
                } else {
                    LazyVStack(spacing: 8) {
                        ForEach(viewModel.items.indices, id: \.self) { index in
                            HistoryRow(item: viewModel.items[index])
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 60)
                }
            }
        }
        .task { await viewModel.load() }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    Task { CacheService.clearAllAPIResponses(); await viewModel.load() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .symbolEffect(.rotate, isActive: viewModel.isLoading)
                }
                .disabled(viewModel.isLoading)
                .help("刷新")
            }
        }
    }
}

private struct HistoryRow: View {
    let item: HistoryItem
    @State private var translation: TranslationResult?

    var body: some View {
        HStack(spacing: 12) {
            AsyncPosterImage(urlString: item.posterURL)
                .frame(width: 44, height: 66)
                .clipShape(RoundedRectangle(cornerRadius: 4))

            VStack(alignment: .leading, spacing: 4) {
                Text(translation?.title ?? item.title)
                    .font(.body)
                    .lineLimit(1)
                Text(item.watchedAt)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(item.mediaType == "movie" ? "电影" : "剧集")
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(.quaternary)
                .clipShape(Capsule())
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .task {
            guard item.traktId > 0 else { return }
            if item.mediaType == "movie" {
                translation = await TranslationService.shared.getMovieTranslation(id: item.traktId)
            } else {
                translation = await TranslationService.shared.getShowTranslation(id: item.traktId)
            }
        }
    }
}
