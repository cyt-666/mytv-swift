import SwiftUI

struct EpisodeDetailView: View {
    let showId: Int
    let seasonNumber: Int
    let episodeNumber: Int
    @State private var viewModel: EpisodeDetailViewModel?
    @State private var listActionViewModel = MediaListActionViewModel()
    @Environment(AppState.self) private var appState
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var isCompact: Bool {
        AdaptiveLayout.isCompact(horizontalSizeClass)
    }

    private var heroHeight: CGFloat {
        isCompact ? 330 : (AdaptiveLayout.runsOnIOS ? 340 : 400)
    }

    private var heroTopPadding: CGFloat {
        isCompact ? 106 : (AdaptiveLayout.runsOnIOS ? 82 : 120)
    }

    var body: some View {
        Group {
            if let viewModel, let episode = viewModel.episode {
                ScrollView {
                    VStack(spacing: 0) {
                        episodeHero(episode: episode, viewModel: viewModel)

                        AdaptiveDetailColumns {
                            VStack(alignment: .leading, spacing: 18) {
                                if let overview = viewModel.translation?.overview ?? episode.overview,
                                   !overview.isEmpty {
                                    DetailSectionCard(title: "简介") {
                                        Text(overview)
                                            .font(.system(size: isCompact ? 14 : 15))
                                            .lineSpacing(isCompact ? 4 : 5)
                                            .foregroundStyle(.secondary)
                                    }
                                }

                                if let show = viewModel.show {
                                    DetailSectionCard(title: "所属剧集") {
                                        showLink(show: show, translation: viewModel.showTranslation)
                                    }
                                }

                                DetailSectionCard(title: "单集信息") {
                                    VStack(spacing: 10) {
                                        DetailInfoRow(title: "季集", value: "第 \(episode.season) 季 第 \(episode.number) 集")

                                        if let firstAired = episode.firstAired {
                                            DetailInfoRow(title: "首播", value: String(firstAired.prefix(10)))
                                        }

                                        if let runtime = episode.runtime {
                                            DetailInfoRow(title: "时长", value: "\(runtime) 分钟")
                                        }

                                        DetailInfoRow(title: "Trakt", value: "\(episode.ids.trakt)")

                                        if let tmdb = episode.ids.tmdb {
                                            DetailInfoRow(title: "TMDB", value: "\(tmdb)")
                                        }

                                        if let tvdb = episode.ids.tvdb {
                                            DetailInfoRow(title: "TVDB", value: "\(tvdb)")
                                        }

                                        if let imdb = episode.ids.imdb, !imdb.isEmpty {
                                            DetailInfoRow(title: "IMDb", value: imdb)
                                        }
                                    }
                                }

                                commentsSection(viewModel: viewModel)
                            }
                        } sidebar: {
                            DetailStatGrid {
                                if let rating = episode.rating {
                                    DetailStatTile(
                                        title: "Trakt 评分",
                                        value: String(format: "%.1f", rating),
                                        icon: "star.fill",
                                        tint: .yellow
                                    )
                                }

                                DetailStatTile(title: "季", value: "\(episode.season)", icon: "rectangle.stack.fill")
                                DetailStatTile(title: "集", value: "\(episode.number)", icon: "play.rectangle.fill")

                                if let runtime = episode.runtime {
                                    DetailStatTile(title: "时长", value: "\(runtime) 分钟", icon: "clock")
                                }

                                if let votes = episode.votes {
                                    DetailStatTile(title: "投票", value: "\(votes)", icon: "person.2.fill")
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
            let vm = EpisodeDetailViewModel(
                showId: showId,
                seasonNumber: seasonNumber,
                episodeNumber: episodeNumber
            )
            self.viewModel = vm
            await vm.load()
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active, let viewModel else { return }
            Task { await viewModel.refreshWatchedStatus() }
        }
    }

    private func episodeHero(episode: EpisodeDTO, viewModel: EpisodeDetailViewModel) -> some View {
        let title = viewModel.translation?.title ?? episode.title ?? "第 \(episode.number) 集"
        let showTitle = viewModel.showTranslation?.title ?? viewModel.show?.title
        let backdropURL = episode.images?.fanart?.first
            ?? episode.images?.screenshot?.first
            ?? viewModel.show?.images?.fanart?.first
            ?? viewModel.show?.images?.poster?.first
        let previewURL = episode.images?.screenshot?.first
            ?? episode.images?.fanart?.first
            ?? viewModel.show?.images?.poster?.first
        let firstAiredDate = DetailWatchedDateFormatter.parse(episode.firstAired)

        return ZStack(alignment: .bottomLeading) {
            DetailHeroArtworkView(urlString: backdropURL, height: heroHeight, dimming: 0.20)

            Group {
                if isCompact {
                    episodeHeroText(
                        episode: episode,
                        title: title,
                        showTitle: showTitle,
                        firstAiredDate: firstAiredDate,
                        viewModel: viewModel,
                        titleSize: 23
                    )
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    HStack(alignment: .bottom, spacing: 24) {
                        previewImage(urlString: previewURL, width: 220)
                        episodeHeroText(
                            episode: episode,
                            title: title,
                            showTitle: showTitle,
                            firstAiredDate: firstAiredDate,
                            viewModel: viewModel,
                            titleSize: 40
                        )
                            .frame(maxWidth: 760, alignment: .leading)
                    }
                }
            }
            .padding(.horizontal, isCompact ? 16 : 32)
            .padding(.bottom, isCompact ? 18 : 28)
            .padding(.top, heroTopPadding)
        }
    }

    private func previewImage(urlString: String?, width: CGFloat) -> some View {
        AsyncPosterImage(urlString: urlString, contentMode: .fit)
            .frame(width: width, height: width * 0.56)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(.white.opacity(0.16), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.38), radius: isCompact ? 10 : 18, y: isCompact ? 6 : 10)
    }

    private func episodeHeroText(
        episode: EpisodeDTO,
        title: String,
        showTitle: String?,
        firstAiredDate: Date?,
        viewModel: EpisodeDetailViewModel,
        titleSize: CGFloat
    ) -> some View {
        VStack(alignment: .leading, spacing: isCompact ? 8 : 12) {
            if let showTitle {
                Text(showTitle)
                    .font(.system(size: isCompact ? 13 : 15, weight: .bold))
                    .foregroundStyle(.white.opacity(0.74))
                    .lineLimit(1)
            }

            Text(title)
                .font(.system(size: titleSize, weight: .bold))
                .foregroundStyle(.white)
                .lineLimit(isCompact ? 3 : 2)
                .minimumScaleFactor(0.82)
                .fixedSize(horizontal: false, vertical: true)
                .shadow(color: .black.opacity(0.35), radius: 8, y: 3)

            FlowLayout(spacing: isCompact ? 6 : 8) {
                DetailMetaChip(text: "S\(episode.season)E\(episode.number)", icon: "play.rectangle.fill", tint: .white.opacity(0.86))

                if let firstAired = episode.firstAired {
                    DetailMetaChip(text: String(firstAired.prefix(10)), icon: "calendar", tint: .white.opacity(0.86))
                }

                if let runtime = episode.runtime {
                    DetailMetaChip(text: "\(runtime) 分钟", icon: "clock", tint: .white.opacity(0.86))
                }

                if let rating = episode.rating {
                    DetailMetaChip(
                        text: String(format: "%.1f", rating),
                        icon: "star.fill",
                        tint: .yellow
                    )
                }
            }

            DetailHeroActionGroup {
                episodeHeroActions(
                    episode: episode,
                    title: title,
                    firstAiredDate: firstAiredDate,
                    viewModel: viewModel
                )
            }
        }
    }

    @ViewBuilder
    private func episodeHeroActions(
        episode: EpisodeDTO,
        title: String,
        firstAiredDate: Date?,
        viewModel: EpisodeDetailViewModel
    ) -> some View {
        MediaListActionMenu(
            target: .episode(episode.ids.trakt),
            viewModel: listActionViewModel
        )

        DetailMarkWatchedButton(
            title: title,
            releaseDate: firstAiredDate,
            releaseDateLabel: L10n.string("首播日期"),
            isSubmitting: viewModel.isMarkingWatched,
            isCheckingStatus: viewModel.isLoadingWatchedStatus,
            isWatched: viewModel.isWatched,
            message: viewModel.watchedMessage,
            errorMessage: viewModel.watchedErrorMessage,
            onMark: { date in
                await viewModel.markWatched(at: date)
            }
        )
    }

    private func showLink(show: ShowDetailsDTO, translation: TranslationResult?) -> some View {
        Button {
            appState.navigate(to: .showDetail(id: showId))
        } label: {
            HStack(spacing: isCompact ? 10 : 14) {
                AsyncPosterImage(urlString: show.images?.poster?.first ?? show.images?.fanart?.first)
                    .frame(width: isCompact ? 48 : 66, height: isCompact ? 72 : 98)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

                VStack(alignment: .leading, spacing: isCompact ? 5 : 7) {
                    Text(translation?.title ?? show.title)
                        .font(.system(size: isCompact ? 14 : 16, weight: .bold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    HStack(spacing: 8) {
                        Text("\(show.year)")

                        if let network = show.network {
                            Text(network)
                        }

                        if let status = show.status {
                            Text(status)
                        }
                    }
                    .font(.system(size: isCompact ? 11 : 12, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                    if let overview = translation?.overview ?? show.overview {
                        Text(overview)
                            .font(.system(size: isCompact ? 11 : 12))
                            .foregroundStyle(.tertiary)
                            .lineLimit(isCompact ? 1 : 2)
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(isCompact ? 10 : 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.quaternary.opacity(0.28))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func commentsSection(viewModel: EpisodeDetailViewModel) -> some View {
        DetailCommentsSection(
            store: viewModel.commentStore,
            isLoggedIn: viewModel.isLoggedIn,
            onSubmit: {
                Task { await viewModel.postComment() }
            }
        )
    }
}
