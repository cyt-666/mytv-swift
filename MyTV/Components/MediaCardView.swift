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
        case .movie(let m): return m.images?.poster?.first
        case .show(let s): return s.images?.poster?.first
        }
    }
}

struct MediaCardView: View {
    let item: MediaItem
    @State private var translation: TranslationResult?
    @State private var isHovered = false
    @Environment(AppState.self) private var appState

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
                        .frame(width: 150, height: 225)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .shadow(color: .black.opacity(0.2), radius: 6, x: 0, y: 3)

                    if let rating = item.rating {
                        RatingBadgeView(rating: rating)
                            .padding(6)
                    }
                }
                .frame(width: 150, height: 225)

                // Title
                Text(translation?.title ?? item.title)
                    .font(.system(size: 14, weight: .medium))
                    .lineLimit(1)
                    .foregroundStyle(.primary)

                // Year
                if let year = item.year {
                    Text(String(year))
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 150)
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
