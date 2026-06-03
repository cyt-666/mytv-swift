import SwiftUI

struct EpisodeDetailView: View {
    let showId: Int
    let seasonNumber: Int
    let episodeNumber: Int
    @State private var viewModel: EpisodeDetailViewModel?
    @Environment(AppState.self) private var appState

    var body: some View {
        Group {
            if let viewModel, let episode = viewModel.episode {
                ScrollView {
                    VStack(spacing: 0) {
                        episodeHero(episode: episode, viewModel: viewModel)

                        HStack(alignment: .top, spacing: 22) {
                            VStack(alignment: .leading, spacing: 18) {
                                if let overview = viewModel.translation?.overview ?? episode.overview,
                                   !overview.isEmpty {
                                    DetailSectionCard(title: "简介") {
                                        Text(overview)
                                            .font(.system(size: 15))
                                            .lineSpacing(5)
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

                            VStack(spacing: 12) {
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
            let vm = EpisodeDetailViewModel(
                showId: showId,
                seasonNumber: seasonNumber,
                episodeNumber: episodeNumber
            )
            self.viewModel = vm
            await vm.load()
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

        return ZStack(alignment: .bottomLeading) {
            DetailHeroArtworkView(urlString: backdropURL, height: 400, dimming: 0.20)

            HStack(alignment: .bottom, spacing: 24) {
                AsyncPosterImage(urlString: previewURL, contentMode: .fit)
                    .frame(width: 220, height: 124)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(.white.opacity(0.16), lineWidth: 1)
                    }
                    .shadow(color: .black.opacity(0.38), radius: 18, y: 10)

                VStack(alignment: .leading, spacing: 12) {
                    if let showTitle {
                        Text(showTitle)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(.white.opacity(0.74))
                            .lineLimit(1)
                    }

                    Text(title)
                        .font(.system(size: 40, weight: .bold))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .shadow(color: .black.opacity(0.35), radius: 8, y: 3)

                    HStack(spacing: 8) {
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
                }
                .frame(maxWidth: 760, alignment: .leading)
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 28)
            .padding(.top, 120)
        }
    }

    private func showLink(show: ShowDetailsDTO, translation: TranslationResult?) -> some View {
        Button {
            appState.navigate(to: .showDetail(id: showId))
        } label: {
            HStack(spacing: 14) {
                AsyncPosterImage(urlString: show.images?.poster?.first ?? show.images?.fanart?.first)
                    .frame(width: 66, height: 98)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

                VStack(alignment: .leading, spacing: 7) {
                    Text(translation?.title ?? show.title)
                        .font(.system(size: 16, weight: .bold))
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
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                    if let overview = translation?.overview ?? show.overview {
                        Text(overview)
                            .font(.system(size: 12))
                            .foregroundStyle(.tertiary)
                            .lineLimit(2)
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(12)
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
