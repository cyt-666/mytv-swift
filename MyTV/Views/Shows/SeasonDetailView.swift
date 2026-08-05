import SwiftUI

struct SeasonDetailView: View {
    let showId: Int
    let seasonNumber: Int
    @State private var viewModel: SeasonDetailViewModel?
    @State private var listActionViewModel = MediaListActionViewModel()
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var isCompact: Bool {
        AdaptiveLayout.isCompact(horizontalSizeClass)
    }

    var body: some View {
        Group {
            if let viewModel, !viewModel.isLoading || !viewModel.episodes.isEmpty {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        seasonHeader(viewModel: viewModel)

                        ForEach(viewModel.episodes, id: \.number) { episode in
                            EpisodeRow(
                                episode: episode,
                                state: viewModel.episodeStates[episode.number],
                                moviePilotTarget: viewModel.moviePilotTarget,
                                showId: showId,
                                seasonNumber: seasonNumber,
                                onDownloaded: {
                                    Task {
                                        await viewModel.loadMoviePilotStatus(forceRefresh: true)
                                    }
                                }
                            )
                        }
                    }
                    .frame(maxWidth: isCompact ? .infinity : 900, alignment: .leading)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.horizontal, isCompact ? 14 : 24)
                    .padding(.top, isCompact ? 12 : (AdaptiveLayout.runsOnIOS ? 24 : 72))
                    .padding(.bottom, 32)
                }
            } else {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task {
            let vm = SeasonDetailViewModel(showId: showId, seasonNumber: seasonNumber)
            self.viewModel = vm
            await vm.load()
        }
    }

    private func seasonHeader(viewModel: SeasonDetailViewModel) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Group {
                if isCompact {
                    VStack(alignment: .leading, spacing: 12) {
                        seasonTitle(viewModel: viewModel)
                        MediaListActionMenu(
                            target: viewModel.season.map { .season($0.ids.trakt) },
                            viewModel: listActionViewModel,
                            prominent: false
                        )
                    }
                } else {
                    HStack(alignment: .top, spacing: 16) {
                        seasonTitle(viewModel: viewModel)

                        Spacer()

                        MediaListActionMenu(
                            target: viewModel.season.map { .season($0.ids.trakt) },
                            viewModel: listActionViewModel,
                            prominent: false
                        )
                    }
                }
            }

            if viewModel.isLoadingMoviePilot {
                Label("正在检查 MoviePilot 单集状态", systemImage: "bolt.horizontal.circle")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
            } else if !viewModel.episodeStates.isEmpty {
                let summary = viewModel.statusSummary
                HStack(spacing: 8) {
                    summaryBadge("已入库", count: summary.inLibrary, tint: .green)
                    summaryBadge("下载中", count: summary.downloading, tint: .blue)
                    summaryBadge("待入库", count: summary.pendingLibrary, tint: .purple)
                    summaryBadge("缺失", count: summary.missing, tint: .red)
                }
            }

            if let error = viewModel.moviePilotErrorMessage {
                HStack(spacing: 10) {
                    Label("MoviePilot 状态暂不可用：\(error)", systemImage: "exclamationmark.triangle.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.orange)

                    Spacer()

                    Button("重试") {
                        Task { await viewModel.loadMoviePilotStatus(forceRefresh: true) }
                    }
                    .buttonStyle(.borderless)
                }
            }
        }
        .padding(.bottom, 8)
    }

    private func seasonTitle(viewModel: SeasonDetailViewModel) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(viewModel.season?.title ?? "第 \(seasonNumber) 季")
                .font(.system(size: isCompact ? 24 : 28, weight: .bold))
                .foregroundStyle(.primary)

            Text("\(viewModel.episodes.count) 集")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
        }
    }

    private func summaryBadge(_ title: String, count: Int, tint: Color) -> some View {
        Text("\(title) \(count)")
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(tint)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(tint.opacity(0.12))
            .clipShape(Capsule())
    }
}

private struct EpisodeRow: View {
    let episode: EpisodeDTO
    let state: MoviePilotEpisodeState?
    let moviePilotTarget: MoviePilotMediaTarget?
    let showId: Int
    let seasonNumber: Int
    let onDownloaded: () -> Void
    @Environment(AppState.self) private var appState
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var isCompact: Bool {
        AdaptiveLayout.isCompact(horizontalSizeClass)
    }

    private var thumbnailWidth: CGFloat {
        isCompact ? 88 : 116
    }

    var body: some View {
        HStack(alignment: .top, spacing: isCompact ? 10 : 12) {
            Button {
                appState.navigate(
                    to: .episodeDetail(
                        showId: showId,
                        seasonNumber: seasonNumber,
                        episodeNumber: episode.number
                    )
                )
            } label: {
                HStack(alignment: .top, spacing: isCompact ? 10 : 12) {
                    AsyncPosterImage(
                        urlString: episode.images?.screenshot?.first ?? episode.images?.fanart?.first,
                        contentMode: .fill
                    )
                    .frame(width: thumbnailWidth, height: thumbnailWidth * 0.56)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .stroke(.primary.opacity(0.08), lineWidth: 1)
                    }

                    VStack(alignment: .leading, spacing: isCompact ? 3 : 5) {
                        Text("E\(episode.number)")
                            .font(.system(size: isCompact ? 11 : 12, weight: .semibold))
                            .foregroundStyle(.secondary)
                        Text(episode.title ?? "")
                            .font(.system(size: isCompact ? 14 : 15, weight: .semibold))
                            .lineLimit(2)
                            .foregroundStyle(.primary)

                        if let overview = episode.overview, !overview.isEmpty {
                            Text(overview)
                                .font(.system(size: isCompact ? 11 : 12))
                                .foregroundStyle(.secondary)
                                .lineLimit(isCompact ? 1 : 2)
                        }
                    }

                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .trailing, spacing: 7) {
                if let state {
                    MoviePilotEpisodeStateBadge(state: state)
                }

                if state == .missing, let moviePilotTarget {
                    MoviePilotResourceSearchButton(
                        target: moviePilotTarget,
                        seasonNumber: seasonNumber,
                        episodeNumber: episode.number,
                        presentation: .compact,
                        onDownloaded: onDownloaded
                    )
                } else if let rating = episode.rating {
                    Label(String(format: "%.1f", rating), systemImage: "star.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.yellow)
                }
            }
        }
        .padding(isCompact ? 10 : 14)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
