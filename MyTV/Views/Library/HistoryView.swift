import SwiftUI

struct HistoryView: View {
    @State private var viewModel = HistoryViewModel()
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var isCompact: Bool {
        AdaptiveLayout.isCompact(horizontalSizeClass)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                if isCompact {
                    filterPicker
                        .padding(.horizontal, 16)
                }

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
                        ForEach(viewModel.items) { item in
                            HistoryRow(item: item)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, isCompact ? 24 : 60)
                }
            }
        }
        .task { await viewModel.load() }
        .onChange(of: viewModel.selectedFilter) { _, _ in
            Task { await viewModel.load() }
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                if !isCompact {
                    filterPicker
                        .frame(width: 220)
                }
            }

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

    private var filterPicker: some View {
        Picker("观看记录类型", selection: $viewModel.selectedFilter) {
            ForEach(HistoryViewModel.Filter.allCases, id: \.self) { filter in
                Text(filter.title).tag(filter)
            }
        }
        .pickerStyle(.segmented)
        .controlSize(.regular)
        .labelsHidden()
    }
}

private struct HistoryRow: View {
    let item: HistoryItem
    @State private var titleTranslation: TranslationResult?
    @State private var episodeTranslation: TranslationResult?

    var body: some View {
        HStack(spacing: 12) {
            AsyncPosterImage(urlString: item.posterURL)
                .frame(width: 44, height: 66)
                .clipShape(RoundedRectangle(cornerRadius: 4))

            VStack(alignment: .leading, spacing: 4) {
                Text(titleTranslation?.title ?? item.title)
                    .font(.body)
                    .lineLimit(1)

                if let episodeLine = item.episodeLine(translatedTitle: episodeTranslation?.title) {
                    Text(episodeLine)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Text(item.watchedAt)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            Text(item.mediaType == "movie" ? L10n.string("电影") : L10n.string("剧集"))
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
                titleTranslation = await TranslationService.shared.getMovieTranslation(id: item.traktId)
            } else if let seasonNumber = item.seasonNumber, let episodeNumber = item.episodeNumber {
                async let showTranslation = TranslationService.shared.getShowTranslation(id: item.traktId)
                async let translatedEpisode = TranslationService.shared.getEpisodeTranslation(
                    showId: item.traktId,
                    seasonNumber: seasonNumber,
                    episodeNumber: episodeNumber
                )
                titleTranslation = await showTranslation
                episodeTranslation = await translatedEpisode
            } else {
                titleTranslation = await TranslationService.shared.getShowTranslation(id: item.traktId)
            }
        }
    }
}
