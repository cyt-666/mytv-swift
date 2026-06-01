import SwiftUI

struct UpNextView: View {
    @State private var viewModel = UpNextViewModel()

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
                        "暂无待看",
                        systemImage: "clock.fill",
                        description: Text("将剧集加入观看清单后，待看进度会显示在这里")
                    )
                    .padding(.top, 100)
                } else {
                    LazyVStack(spacing: 8) {
                        ForEach(viewModel.items.indices, id: \.self) { index in
                            UpNextRow(item: viewModel.items[index])
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

private struct UpNextRow: View {
    let item: UpNextItemDTO
    @State private var showTranslation: TranslationResult?
    @State private var episodeTranslation: TranslationResult?
    @State private var isHovered = false
    @Environment(AppState.self) private var appState

    var body: some View {
        Button {
            appState.navigate(
                to: .episodeDetail(
                    showId: item.show.ids.trakt,
                    seasonNumber: item.nextEpisode.season,
                    episodeNumber: item.nextEpisode.number
                )
            )
        } label: {
            HStack(spacing: 12) {
                AsyncPosterImage(urlString: item.show.images?.poster?.first)
                    .frame(width: 60, height: 90)
                    .clipShape(RoundedRectangle(cornerRadius: 6))

                VStack(alignment: .leading, spacing: 6) {
                    Text(showTranslation?.title ?? item.show.title)
                        .font(.body)
                        .fontWeight(.medium)
                        .lineLimit(1)
                        .foregroundStyle(.primary)

                    Text("S\(item.nextEpisode.season)E\(item.nextEpisode.number) - \(episodeTranslation?.title ?? item.nextEpisode.title ?? "")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    // Progress bar
                    ProgressView(value: Double(item.displayCompletedEpisodes), total: Double(item.displayAiredEpisodes))
                        .tint(.blue)

                    Text("\(item.displayCompletedEpisodes)/\(item.displayAiredEpisodes) 集已看")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding()
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(.primary.opacity(isHovered ? 0.12 : 0.06), lineWidth: 1)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .task {
            async let showTr = TranslationService.shared.getShowTranslation(id: item.show.ids.trakt)
            async let epTr = TranslationService.shared.getEpisodeTranslation(
                showId: item.show.ids.trakt,
                seasonNumber: item.nextEpisode.season,
                episodeNumber: item.nextEpisode.number
            )
            showTranslation = await showTr
            episodeTranslation = await epTr
        }
    }
}
