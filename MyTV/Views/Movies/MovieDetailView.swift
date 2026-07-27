import SwiftUI

struct MovieDetailView: View {
    let movieId: Int
    @State private var viewModel: MovieDetailViewModel?
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
            if let viewModel, let movie = viewModel.movie {
                let moviePilotTarget = MoviePilotMediaTarget.movie(movie)
                ScrollView {
                    VStack(spacing: 0) {
                        movieHero(movie: movie, translation: viewModel.translation, detailViewModel: viewModel)

                        AdaptiveDetailColumns {
                            VStack(alignment: .leading, spacing: 18) {
                                if let overview = viewModel.translation?.overview ?? movie.overview {
                                    DetailSectionCard(title: "简介") {
                                        Text(overview)
                                            .font(.system(size: isCompact ? 14 : 15))
                                            .lineSpacing(isCompact ? 4 : 5)
                                            .foregroundStyle(.secondary)
                                    }
                                }

                                if let genres = movie.genres, !genres.isEmpty {
                                    DetailSectionCard(title: "类型") {
                                        DetailGenreCloud(genres: genres)
                                    }
                                }

                                DetailSectionCard(title: "媒体信息") {
                                    VStack(spacing: 10) {
                                        if let originalTitle = movie.originalTitle, originalTitle != movie.title {
                                            DetailInfoRow(title: "原名", value: originalTitle)
                                        }
                                        if let released = movie.released {
                                            DetailInfoRow(title: "上映", value: released)
                                        }
                                        if let country = movie.country {
                                            DetailInfoRow(title: "地区", value: country.uppercased())
                                        }
                                        if let status = movie.status {
                                            DetailInfoRow(title: "状态", value: status)
                                        }
                                        if let certification = movie.certification {
                                            DetailInfoRow(title: "分级", value: certification)
                                        }
                                        if let languages = movie.languages, !languages.isEmpty {
                                            DetailInfoRow(title: "语言", value: languages.joined(separator: ", "))
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
                                    if let rating = movie.rating {
                                        DetailStatTile(
                                            title: "Trakt 评分",
                                            value: String(format: "%.1f", rating),
                                            icon: "star.fill",
                                            tint: .yellow
                                        )
                                    }

                                    DetailStatTile(title: "年份", value: "\(movie.year)", icon: "calendar")

                                    if let runtime = movie.runtime {
                                        DetailStatTile(title: "片长", value: "\(runtime) 分钟", icon: "clock")
                                    }

                                    if let votes = movie.votes {
                                        DetailStatTile(title: "投票", value: "\(votes)", icon: "person.2.fill")
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
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task {
            let vm = MovieDetailViewModel(movieId: movieId)
            self.viewModel = vm
            await vm.load()
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active, let viewModel else { return }
            Task { await viewModel.refreshWatchedStatus() }
        }
    }

    private func movieHero(
        movie: MovieDetailsDTO,
        translation: TranslationResult?,
        detailViewModel: MovieDetailViewModel
    ) -> some View {
        let title = translation?.title ?? movie.title
        let tagline = translation?.tagline ?? movie.tagline
        let backdropURL = movie.images?.fanart?.first ?? movie.images?.poster?.first
        let moviePilotTarget = MoviePilotMediaTarget.movie(movie)
        let releaseDate = DetailWatchedDateFormatter.parse(movie.released)

        return ZStack(alignment: .bottomLeading) {
            DetailHeroArtworkView(urlString: backdropURL, height: heroHeight, dimming: 0.18)

            heroContent(
                posterURL: movie.images?.poster?.first,
                title: title,
                subtitle: tagline,
                chips: {
                    DetailMetaChip(text: "\(movie.year)", icon: "calendar", tint: .white.opacity(0.86))
                    if let runtime = movie.runtime {
                        DetailMetaChip(text: "\(runtime) 分钟", icon: "clock", tint: .white.opacity(0.86))
                    }
                    if let rating = movie.rating {
                        DetailMetaChip(
                            text: String(format: "%.1f", rating),
                            icon: "star.fill",
                            tint: .yellow
                        )
                    }
                },
                actions: {
                    MediaListActionMenu(
                        target: .movie(movie.ids.trakt),
                        viewModel: listActionViewModel
                    )

                    DetailMarkWatchedButton(
                        title: title,
                        releaseDate: releaseDate,
                        releaseDateLabel: L10n.string("上映日期"),
                        isSubmitting: detailViewModel.isMarkingWatched,
                        isCheckingStatus: detailViewModel.isLoadingWatchedStatus,
                        isWatched: detailViewModel.isWatched,
                        watchedAt: detailViewModel.watchedAt,
                        message: detailViewModel.watchedMessage,
                        errorMessage: detailViewModel.watchedErrorMessage,
                        onMark: { date in
                            await detailViewModel.markWatched(at: date)
                        }
                    )

                    if appState.isMediaAssistantConfigured {
                        MoviePilotSubscribeButton(
                            target: moviePilotTarget,
                            viewModel: moviePilotViewModel,
                            onConfigure: navigateToSettings
                        )
                    }
                }
            )
        }
    }

    private func heroContent<Chips: View, Actions: View>(
        posterURL: String?,
        title: String,
        subtitle: String?,
        @ViewBuilder chips: () -> Chips,
        @ViewBuilder actions: () -> Actions
    ) -> some View {
        Group {
            if isCompact {
                heroText(title: title, subtitle: subtitle, titleSize: 23, chips: chips, actions: actions)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                HStack(alignment: .bottom, spacing: 24) {
                    AsyncPosterImage(urlString: posterURL)
                        .frame(width: 170, height: 255)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .shadow(color: .black.opacity(0.38), radius: 18, y: 10)

                    heroText(title: title, subtitle: subtitle, titleSize: 42, chips: chips, actions: actions)
                        .frame(maxWidth: 720, alignment: .leading)
                }
            }
        }
        .padding(.horizontal, isCompact ? 16 : 32)
        .padding(.bottom, isCompact ? 18 : 28)
        .padding(.top, heroTopPadding)
    }

    private func heroText<Chips: View, Actions: View>(
        title: String,
        subtitle: String?,
        titleSize: CGFloat,
        @ViewBuilder chips: () -> Chips,
        @ViewBuilder actions: () -> Actions
    ) -> some View {
        VStack(alignment: .leading, spacing: isCompact ? 9 : 14) {
            Text(title)
                .font(.system(size: titleSize, weight: .bold))
                .foregroundStyle(.white)
                .lineLimit(isCompact ? 3 : 2)
                .minimumScaleFactor(0.82)
                .fixedSize(horizontal: false, vertical: true)
                .shadow(color: .black.opacity(0.35), radius: 8, y: 3)

            if let subtitle, !subtitle.isEmpty {
                Text(subtitle)
                    .font(.system(size: isCompact ? 14 : 16, weight: .medium))
                    .foregroundStyle(.white.opacity(0.78))
                    .lineLimit(2)
            }

            FlowLayout(spacing: isCompact ? 6 : 8) {
                chips()
            }

            DetailHeroActionGroup {
                actions()
            }
        }
    }

    private func commentsSection(viewModel: MovieDetailViewModel) -> some View {
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

// Simple flow layout for genre tags
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
        }
    }

    private func arrangeSubviews(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var maxX: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
            maxX = max(maxX, x)
        }

        let resolvedWidth = maxWidth.isFinite ? min(maxX, maxWidth) : maxX
        return (CGSize(width: resolvedWidth, height: y + rowHeight), positions)
    }
}
