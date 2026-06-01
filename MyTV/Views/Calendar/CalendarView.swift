import SwiftUI

struct CalendarView: View {
    @State private var viewModel = CalendarViewModel()

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if viewModel.isLoading && viewModel.groupedShows.isEmpty {
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
                } else if viewModel.groupedShows.isEmpty {
                    ContentUnavailableView(
                        "暂无日程",
                        systemImage: "calendar",
                        description: Text("将剧集加入观看清单后，播出日历会显示在这里")
                    )
                    .padding(.top, 100)
                } else {
                    LazyVStack(spacing: 16) {
                        ForEach(viewModel.groupedShows, id: \.date) { group in
                            VStack(alignment: .leading, spacing: 8) {
                                Text(group.date)
                                    .font(.headline)
                                    .padding(.horizontal, 20)

                                ForEach(group.shows.indices, id: \.self) { index in
                                    CalendarShowRow(show: group.shows[index])
                                }
                            }
                        }
                    }
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

private struct CalendarShowRow: View {
    let show: CalendarShowDTO
    @State private var showTranslation: TranslationResult?
    @State private var episodeTranslation: TranslationResult?

    var body: some View {
        HStack(spacing: 12) {
            AsyncPosterImage(urlString: show.show.images?.poster?.first)
                .frame(width: 44, height: 66)
                .clipShape(RoundedRectangle(cornerRadius: 4))

            VStack(alignment: .leading, spacing: 4) {
                Text(showTranslation?.title ?? show.show.title)
                    .font(.body)
                    .lineLimit(1)
                if let episode = show.episode {
                    Text("S\(episode.season)E\(episode.number) - \(episodeTranslation?.title ?? episode.title ?? "")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()
        }
        .padding(.horizontal, 20)
        .task {
            async let showTr = TranslationService.shared.getShowTranslation(id: show.show.ids.trakt)
            if let episode = show.episode {
                async let epTr = TranslationService.shared.getEpisodeTranslation(
                    showId: show.show.ids.trakt,
                    seasonNumber: episode.season,
                    episodeNumber: episode.number
                )
                showTranslation = await showTr
                episodeTranslation = await epTr
            } else {
                showTranslation = await showTr
            }
        }
    }
}
