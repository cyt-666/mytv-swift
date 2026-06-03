import SwiftUI

struct MovieDetailView: View {
    let movieId: Int
    @State private var viewModel: MovieDetailViewModel?

    var body: some View {
        Group {
            if let viewModel, let movie = viewModel.movie {
                ScrollView {
                    VStack(spacing: 0) {
                        movieHero(movie: movie, translation: viewModel.translation)

                        HStack(alignment: .top, spacing: 22) {
                            VStack(alignment: .leading, spacing: 18) {
                                if let overview = viewModel.translation?.overview ?? movie.overview {
                                    DetailSectionCard(title: "简介") {
                                        Text(overview)
                                            .font(.system(size: 15))
                                            .lineSpacing(5)
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

                            VStack(spacing: 12) {
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
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task {
            let vm = MovieDetailViewModel(movieId: movieId)
            self.viewModel = vm
            await vm.load()
        }
    }

    private func movieHero(movie: MovieDetailsDTO, translation: TranslationResult?) -> some View {
        let title = translation?.title ?? movie.title
        let tagline = translation?.tagline ?? movie.tagline
        let backdropURL = movie.images?.fanart?.first ?? movie.images?.poster?.first

        return ZStack(alignment: .bottomLeading) {
            DetailHeroArtworkView(urlString: backdropURL, height: 420, dimming: 0.18)

            HStack(alignment: .bottom, spacing: 24) {
                AsyncPosterImage(urlString: movie.images?.poster?.first)
                    .frame(width: 170, height: 255)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .shadow(color: .black.opacity(0.38), radius: 18, y: 10)

                VStack(alignment: .leading, spacing: 14) {
                    Text(title)
                        .font(.system(size: 42, weight: .bold))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .shadow(color: .black.opacity(0.35), radius: 8, y: 3)

                    if let tagline, !tagline.isEmpty {
                        Text(tagline)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(.white.opacity(0.78))
                            .lineLimit(2)
                    }

                    HStack(spacing: 8) {
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
                    }
                }
                .frame(maxWidth: 720, alignment: .leading)
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 28)
            .padding(.top, 120)
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

        return (CGSize(width: maxX, height: y + rowHeight), positions)
    }
}
