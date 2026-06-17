import SwiftUI

struct ShowDetailView: View {
    let showId: Int
    @State private var viewModel: ShowDetailViewModel?
    @State private var listActionViewModel = MediaListActionViewModel()
    @State private var moviePilotViewModel = MoviePilotMediaViewModel()
    @Environment(AppState.self) private var appState

    var body: some View {
        Group {
            if let viewModel, let show = viewModel.show {
                let moviePilotTarget = MoviePilotMediaTarget.show(show)
                ScrollView {
                    VStack(spacing: 0) {
                        showHero(show: show, translation: viewModel.translation, seasons: viewModel.seasons)

                        HStack(alignment: .top, spacing: 22) {
                            VStack(alignment: .leading, spacing: 18) {
                                if let overview = viewModel.translation?.overview ?? show.overview {
                                    DetailSectionCard(title: "简介") {
                                        Text(overview)
                                            .font(.system(size: 15))
                                            .lineSpacing(5)
                                            .foregroundStyle(.secondary)
                                    }
                                }

                                if let genres = show.genres, !genres.isEmpty {
                                    DetailSectionCard(title: "类型") {
                                        DetailGenreCloud(genres: genres)
                                    }
                                }

                                if !viewModel.seasons.isEmpty {
                                    DetailSectionCard(title: "季度") {
                                        LazyVGrid(
                                            columns: [GridItem(.adaptive(minimum: 220), spacing: 12)],
                                            spacing: 12
                                        ) {
                                            ForEach(viewModel.seasons, id: \.number) { season in
                                                SeasonCard(season: season, showId: showId)
                                            }
                                        }
                                    }
                                }

                                DetailSectionCard(title: "剧集信息") {
                                    VStack(spacing: 10) {
                                        if let originalTitle = show.originalTitle, originalTitle != show.title {
                                            DetailInfoRow(title: "原名", value: originalTitle)
                                        }
                                        if let status = show.status {
                                            DetailInfoRow(title: "状态", value: status)
                                        }
                                        if let network = show.network {
                                            DetailInfoRow(title: "电视网", value: network)
                                        }
                                        if let country = show.country {
                                            DetailInfoRow(title: "地区", value: country.uppercased())
                                        }
                                        if let languages = show.languages, !languages.isEmpty {
                                            DetailInfoRow(title: "语言", value: languages.joined(separator: ", "))
                                        }
                                        if let firstAired = show.firstAired {
                                            DetailInfoRow(title: "首播", value: firstAired)
                                        }
                                    }
                                }

                                commentsSection(viewModel: viewModel)
                            }

                            VStack(spacing: 12) {
                                MoviePilotStatusPanel(
                                    target: moviePilotTarget,
                                    viewModel: moviePilotViewModel,
                                    onConfigure: navigateToSettings
                                )

                                if let rating = show.rating {
                                    DetailStatTile(
                                        title: "Trakt 评分",
                                        value: String(format: "%.1f", rating),
                                        icon: "star.fill",
                                        tint: .yellow
                                    )
                                }

                                DetailStatTile(title: "年份", value: "\(show.year)", icon: "calendar")

                                if !viewModel.seasons.isEmpty {
                                    DetailStatTile(title: "季数", value: "\(viewModel.seasons.count)", icon: "rectangle.stack.fill")
                                }

                                if let episodes = show.airedEpisodes {
                                    DetailStatTile(title: "集数", value: "\(episodes)", icon: "play.rectangle.fill")
                                }
                            }
                            .frame(width: 220)
                        }
                        .padding(.horizontal, 28)
                        .padding(.top, 24)
                        .padding(.bottom, 40)
                    }
                }
                .background(DetailBackgroundClearer())
                .ignoresSafeArea(.container, edges: .top)
            } else {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task {
            let vm = ShowDetailViewModel(showId: showId)
            vm.configure(appState: appState)
            self.viewModel = vm
            await vm.load()
        }
    }

    private func showHero(show: ShowDetailsDTO, translation: TranslationResult?, seasons: [SeasonDTO]) -> some View {
        let title = translation?.title ?? show.title
        let backdropURL = show.images?.fanart?.first ?? show.images?.poster?.first
        let moviePilotTarget = MoviePilotMediaTarget.show(show)

        return ZStack(alignment: .bottomLeading) {
            DetailHeroArtworkView(urlString: backdropURL, height: 420, dimming: 0.18)

            HStack(alignment: .bottom, spacing: 24) {
                AsyncPosterImage(urlString: show.images?.poster?.first)
                    .frame(width: 170, height: 255)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .shadow(color: .black.opacity(0.38), radius: 18, y: 10)

                VStack(alignment: .leading, spacing: 14) {
                    Text(title)
                        .font(.system(size: 42, weight: .bold))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .shadow(color: .black.opacity(0.35), radius: 8, y: 3)

                    if let network = show.network {
                        Text(network)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(.white.opacity(0.78))
                            .lineLimit(1)
                    }

                    HStack(spacing: 8) {
                        DetailMetaChip(text: "\(show.year)", icon: "calendar", tint: .white.opacity(0.86))
                        if let status = show.status {
                            DetailMetaChip(text: status, icon: "dot.radiowaves.left.and.right", tint: .white.opacity(0.86))
                        }
                        if let runtime = show.runtime {
                            DetailMetaChip(text: "\(runtime) 分钟/集", icon: "clock", tint: .white.opacity(0.86))
                        }
                        if let rating = show.rating {
                            DetailMetaChip(
                                text: String(format: "%.1f", rating),
                                icon: "star.fill",
                                tint: .yellow
                            )
                        }
                    }

                    HStack(spacing: 10) {
                        MediaListActionMenu(
                            target: .show(show.ids.trakt),
                            viewModel: listActionViewModel
                        )

                        MoviePilotSubscribeButton(
                            target: moviePilotTarget,
                            seasons: seasons,
                            viewModel: moviePilotViewModel,
                            onConfigure: navigateToSettings
                        )
                    }
                }
                .frame(maxWidth: 720, alignment: .leading)
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 28)
            .padding(.top, 120)
        }
    }

    private func commentsSection(viewModel: ShowDetailViewModel) -> some View {
        DetailCommentsSection(
            store: viewModel.commentStore,
            isLoggedIn: viewModel.isLoggedIn,
            onSubmit: {
                Task { await viewModel.postComment() }
            }
        )
    }

    private func navigateToSettings() {
        appState.navigate(to: .settings)
    }
}

private struct SeasonCard: View {
    let season: SeasonDTO
    let showId: Int
    @State private var isHovered = false
    @Environment(AppState.self) private var appState

    var body: some View {
        Button {
            appState.navigate(to: .seasonDetail(showId: showId, seasonNumber: season.number))
        } label: {
            HStack(spacing: 12) {
                AsyncPosterImage(urlString: season.images?.poster?.first ?? season.images?.fanart?.first)
                    .frame(width: 56, height: 78)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

                VStack(alignment: .leading, spacing: 6) {
                    Text(season.title ?? "第 \(season.number) 季")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    HStack(spacing: 8) {
                        if let episodeCount = season.episodeCount {
                            Text("\(episodeCount) 集")
                        }
                        if let rating = season.rating {
                            Label(String(format: "%.1f", rating), systemImage: "star.fill")
                                .foregroundStyle(.yellow)
                        }
                    }
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(.quaternary.opacity(isHovered ? 0.5 : 0.25))
            }
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}
