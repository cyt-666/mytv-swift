import SwiftUI

enum MediaItem: Hashable, Identifiable {
    case movie(MovieDTO)
    case show(ShowDTO)

    var id: String {
        switch self {
        case .movie(let m): return "movie-\(m.ids.trakt)"
        case .show(let s): return "show-\(s.ids.trakt)"
        }
    }

    var title: String {
        switch self {
        case .movie(let m): return m.title
        case .show(let s): return s.title
        }
    }

    var year: Int? {
        switch self {
        case .movie(let m): return m.year
        case .show(let s): return s.year
        }
    }

    var rating: Double? {
        switch self {
        case .movie(let m): return m.rating
        case .show(let s): return s.rating
        }
    }

    var posterURL: String? {
        switch self {
        case .movie(let m): return m.images?.bestPosterURL
        case .show(let s): return s.images?.bestPosterURL
        }
    }
}

struct MediaCardView: View {
    let item: MediaItem
    var posterWidth: CGFloat = 150
    @State private var translation: TranslationResult?
    @State private var isHovered = false
    @Environment(AppState.self) private var appState

    private var posterHeight: CGFloat {
        posterWidth * 1.5
    }

    private var isCompactCard: Bool {
        posterWidth < 120
    }

    private var titleLineLimit: Int {
        isCompactCard ? 2 : 1
    }

    private var titleHeight: CGFloat {
        isCompactCard ? 32 : 18
    }

    private var yearHeight: CGFloat {
        isCompactCard ? 14 : 16
    }

    var body: some View {
        Button {
            switch item {
            case .movie(let m):
                appState.navigate(to: .movieDetail(id: m.ids.trakt))
            case .show(let s):
                appState.navigate(to: .showDetail(id: s.ids.trakt))
            }
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                // Poster
                ZStack(alignment: .topTrailing) {
                    AsyncPosterImage(urlString: item.posterURL)
                        .frame(width: posterWidth, height: posterHeight)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .shadow(color: .black.opacity(0.2), radius: 6, x: 0, y: 3)

                    if let rating = item.rating {
                        RatingBadgeView(rating: rating)
                            .scaleEffect(isCompactCard ? 0.86 : 1.0, anchor: .topTrailing)
                            .padding(isCompactCard ? 4 : 6)
                    }
                }
                .frame(width: posterWidth, height: posterHeight)

                // Title
                Text(translation?.title ?? item.title)
                    .font(.system(size: isCompactCard ? 12 : 14, weight: .medium))
                    .lineLimit(titleLineLimit)
                    .multilineTextAlignment(.leading)
                    .foregroundStyle(.primary)
                    .frame(width: posterWidth, height: titleHeight, alignment: .topLeading)

                // Year
                Text(item.year.map(String.init) ?? "")
                    .font(.system(size: isCompactCard ? 11 : 12))
                    .foregroundStyle(.secondary)
                    .frame(width: posterWidth, height: yearHeight, alignment: .topLeading)
            }
            .frame(width: posterWidth, alignment: .topLeading)
            .contentShape(Rectangle())
            .scaleEffect(isHovered ? 1.03 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: isHovered)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .task { await loadTranslation() }
    }

    private func loadTranslation() async {
        let service = TranslationService.shared
        switch item {
        case .movie(let m):
            translation = await service.getMovieTranslation(id: m.ids.trakt)
        case .show(let s):
            translation = await service.getShowTranslation(id: s.ids.trakt)
        }
    }
}
