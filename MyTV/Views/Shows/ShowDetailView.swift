import SwiftUI

struct ShowDetailView: View {
    let showId: Int
    @State private var viewModel: ShowDetailViewModel?
    @State private var listActionViewModel = MediaListActionViewModel()
    @State private var moviePilotViewModel = MoviePilotMediaViewModel()
    @Environment(AppState.self) private var appState
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var isCompact: Bool {
        AdaptiveLayout.isCompact(horizontalSizeClass)
    }

    private var heroHeight: CGFloat {
        isCompact ? 360 : (AdaptiveLayout.runsOnIOS ? 360 : 420)
    }

    private var heroTopPadding: CGFloat {
        isCompact ? 110 : (AdaptiveLayout.runsOnIOS ? 88 : 120)
    }

    var body: some View {
        Group {
            if let viewModel, let show = viewModel.show {
                let moviePilotTarget = MoviePilotMediaTarget.show(show)
                ScrollView {
                    VStack(spacing: 0) {
                        showHero(show: show, translation: viewModel.translation, seasons: viewModel.seasons, detailViewModel: viewModel)

                        AdaptiveDetailColumns {
                            VStack(alignment: .leading, spacing: 18) {
                                if let overview = viewModel.translation?.overview ?? show.overview {
                                    DetailSectionCard(title: "简介") {
                                        Text(overview)
                                            .font(.system(size: isCompact ? 14 : 15))
                                            .lineSpacing(isCompact ? 4 : 5)
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
                                            columns: [
                                                GridItem(
                                                    .adaptive(minimum: isCompact ? 148 : 220),
                                                    spacing: isCompact ? 10 : 12
                                                )
                                            ],
                                            spacing: isCompact ? 10 : 12
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
                        } sidebar: {
                            VStack(spacing: isCompact ? 10 : 12) {
                                if appState.isMediaAssistantConfigured {
                                    MoviePilotStatusPanel(
                                        target: moviePilotTarget,
                                        viewModel: moviePilotViewModel,
                                        onConfigure: navigateToSettings
                                    )
                                }

                                DetailStatGrid {
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
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .top)
                }
                .background(DetailBackgroundClearer())
                .detailTopSafeAreaBleed(isCompact)
                .detailNavigationBarBackgroundHidden(isCompact)
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
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active, let viewModel else { return }
            Task { await viewModel.refreshWatchedStatus() }
        }
    }

    private func showHero(
        show: ShowDetailsDTO,
        translation: TranslationResult?,
        seasons: [SeasonDTO],
        detailViewModel: ShowDetailViewModel
    ) -> some View {
        let title = translation?.title ?? show.title
        let backdropURL = show.images?.fanart?.first ?? show.images?.poster?.first
        let moviePilotTarget = MoviePilotMediaTarget.show(show)
        let firstAiredDate = DetailWatchedDateFormatter.parse(show.firstAired)

        return ZStack(alignment: .bottomLeading) {
            DetailHeroArtworkView(urlString: backdropURL, height: heroHeight, dimming: 0.18)

            Group {
                if isCompact {
                    heroText(
                        show: show,
                        title: title,
                        network: show.network,
                        seasons: seasons,
                        moviePilotTarget: moviePilotTarget,
                        firstAiredDate: firstAiredDate,
                        detailViewModel: detailViewModel,
                        titleSize: 23
                    )
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    HStack(alignment: .bottom, spacing: 24) {
                        heroPoster(urlString: show.images?.poster?.first, width: 170)
                        heroText(
                            show: show,
                            title: title,
                            network: show.network,
                            seasons: seasons,
                            moviePilotTarget: moviePilotTarget,
                            firstAiredDate: firstAiredDate,
                            detailViewModel: detailViewModel,
                            titleSize: 42
                        )
                            .frame(maxWidth: 720, alignment: .leading)
                    }
                }
            }
            .padding(.horizontal, isCompact ? 16 : 32)
            .padding(.bottom, isCompact ? 18 : 28)
            .padding(.top, heroTopPadding)
        }
    }

    private func heroPoster(urlString: String?, width: CGFloat) -> some View {
        AsyncPosterImage(urlString: urlString)
            .frame(width: width, height: width * 1.5)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .shadow(color: .black.opacity(0.38), radius: isCompact ? 10 : 18, y: isCompact ? 6 : 10)
    }

    private func heroText(
        show: ShowDetailsDTO,
        title: String,
        network: String?,
        seasons: [SeasonDTO],
        moviePilotTarget: MoviePilotMediaTarget,
        firstAiredDate: Date?,
        detailViewModel: ShowDetailViewModel,
        titleSize: CGFloat
    ) -> some View {
        VStack(alignment: .leading, spacing: isCompact ? 9 : 14) {
            Text(title)
                .font(.system(size: titleSize, weight: .bold))
                .foregroundStyle(.white)
                .lineLimit(isCompact ? 3 : 2)
                .minimumScaleFactor(0.82)
                .fixedSize(horizontal: false, vertical: true)
                .shadow(color: .black.opacity(0.35), radius: 8, y: 3)

            if let network {
                Text(network)
                    .font(.system(size: isCompact ? 14 : 16, weight: .medium))
                    .foregroundStyle(.white.opacity(0.78))
                    .lineLimit(1)
            }

            FlowLayout(spacing: isCompact ? 6 : 8) {
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

            DetailHeroActionGroup {
                heroActions(
                    show: show,
                    seasons: seasons,
                    moviePilotTarget: moviePilotTarget,
                    firstAiredDate: firstAiredDate,
                    detailViewModel: detailViewModel
                )
            }
        }
    }

    @ViewBuilder
    private func heroActions(
        show: ShowDetailsDTO,
        seasons: [SeasonDTO],
        moviePilotTarget: MoviePilotMediaTarget,
        firstAiredDate: Date?,
        detailViewModel: ShowDetailViewModel
    ) -> some View {
        MediaListActionMenu(
            target: .show(show.ids.trakt),
            viewModel: listActionViewModel
        )

        DetailMarkWatchedButton(
            title: detailViewModel.translation?.title ?? show.title,
            releaseDate: firstAiredDate,
            releaseDateLabel: L10n.string("首播日期"),
            isSubmitting: detailViewModel.isMarkingWatched,
            isCheckingStatus: detailViewModel.isLoadingWatchedStatus,
            isWatched: detailViewModel.isWatched,
            message: detailViewModel.watchedMessage,
            errorMessage: detailViewModel.watchedErrorMessage,
            onMark: { date in
                await detailViewModel.markWatched(at: date)
            }
        )

        if appState.isMediaAssistantConfigured {
            MoviePilotSubscribeButton(
                target: moviePilotTarget,
                seasons: seasons,
                viewModel: moviePilotViewModel,
                onConfigure: navigateToSettings
            )
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
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var isCompact: Bool {
        AdaptiveLayout.isCompact(horizontalSizeClass)
    }

    private var posterWidth: CGFloat {
        isCompact ? 44 : 56
    }

    var body: some View {
        Button {
            appState.navigate(to: .seasonDetail(showId: showId, seasonNumber: season.number))
        } label: {
            HStack(spacing: isCompact ? 9 : 12) {
                AsyncPosterImage(urlString: season.images?.poster?.first ?? season.images?.fanart?.first)
                    .frame(width: posterWidth, height: posterWidth * 1.42)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

                VStack(alignment: .leading, spacing: isCompact ? 4 : 6) {
                    Text(season.title ?? "第 \(season.number) 季")
                        .font(.system(size: isCompact ? 13 : 14, weight: .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(isCompact ? 2 : 1)

                    HStack(spacing: isCompact ? 6 : 8) {
                        if let episodeCount = season.episodeCount {
                            Text("\(episodeCount) 集")
                        }
                        if let rating = season.rating {
                            Label(String(format: "%.1f", rating), systemImage: "star.fill")
                                .foregroundStyle(.yellow)
                        }
                    }
                    .font(.system(size: isCompact ? 11 : 12, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(isCompact ? 10 : 12)
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
