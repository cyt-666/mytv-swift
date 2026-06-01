import SwiftUI

struct HeroCarouselView: View {
    let movies: [MovieDTO]
    var contentLeadingInset: CGFloat = 48
    @Environment(AppState.self) private var appState
    @State private var currentIndex = 0
    @State private var translations: [Int: TranslationResult] = [:]
    private let heroHeight: CGFloat = 500

    var body: some View {
        ZStack(alignment: .bottom) {
            // Slides
            ForEach(Array(movies.enumerated()), id: \.offset) { index, movie in
                HeroSlide(
                    movie: movie,
                    translation: translations[movie.ids.trakt],
                    contentLeadingInset: contentLeadingInset
                )
                    .opacity(index == currentIndex ? 1 : 0)
                    .animation(.easeInOut(duration: 0.6), value: currentIndex)
            }

            // Bottom gradient overlay
            LinearGradient(
                colors: [.clear, .black.opacity(0.7)],
                startPoint: .center,
                endPoint: .bottom
            )
            .allowsHitTesting(false)

            // Page indicators
            HStack(spacing: 8) {
                ForEach(0..<movies.count, id: \.self) { index in
                    Circle()
                        .fill(index == currentIndex ? .white : .white.opacity(0.5))
                        .frame(width: 8, height: 8)
                        .animation(.easeInOut, value: currentIndex)
                }
            }
            .padding(.bottom, 16)
        }
        .frame(maxWidth: .infinity)
        .frame(height: heroHeight)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(.white.opacity(0.10), lineWidth: 1)
        }
        .onAppear {
            loadTranslations()
            appState.homeFanartURL = movies.first?.images?.fanart?.first
        }
        .onChange(of: currentIndex) { _, newIndex in
            withAnimation(.easeInOut(duration: 0.8)) {
                appState.homeFanartURL = movies.indices.contains(newIndex) ? movies[newIndex].images?.fanart?.first : nil
            }
        }
        .onReceive(Timer.publish(every: 5, on: .main, in: .common).autoconnect()) { _ in
            withAnimation(.easeInOut(duration: 0.6)) {
                currentIndex = (currentIndex + 1) % max(movies.count, 1)
            }
        }
    }

    private func loadTranslations() {
        for movie in movies.prefix(5) {
            Task {
                let result = await TranslationService.shared.getMovieTranslation(id: movie.ids.trakt)
                if let result {
                    translations[movie.ids.trakt] = result
                }
            }
        }
    }
}

private struct HeroSlide: View {
    let movie: MovieDTO
    let translation: TranslationResult?
    let contentLeadingInset: CGFloat

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            // Background image
            if let fanart = movie.images?.fanart?.first {
                AsyncPosterImage(urlString: fanart)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
            } else {
                Rectangle()
                    .fill(.quaternary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            // Dark overlay
            LinearGradient(
                colors: [.black.opacity(0.48), .black.opacity(0.08), .black.opacity(0.32)],
                startPoint: .leading,
                endPoint: .trailing
            )

            LinearGradient(
                colors: [.clear, .black.opacity(0.56)],
                startPoint: .center,
                endPoint: .bottom
            )

            // Content
            VStack(alignment: .leading, spacing: 10) {
                Text(translation?.title ?? movie.title)
                    .font(.system(size: 36, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                if let overview = translation?.overview ?? movie.overview {
                    Text(overview)
                        .font(.system(size: 15))
                        .foregroundStyle(.white.opacity(0.85))
                        .lineLimit(2)
                }

                // Meta pills
                HStack(spacing: 10) {
                    if let year = movie.year {
                        Text(String(year))
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(.white.opacity(0.15))
                            .clipShape(Capsule())
                    }

                    if let rating = movie.rating {
                        HStack(spacing: 4) {
                            Image(systemName: "star.fill")
                                .font(.system(size: 11))
                            Text(String(format: "%.1f", rating))
                                .font(.system(size: 13, weight: .semibold))
                        }
                        .foregroundStyle(.yellow)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(.black.opacity(0.4))
                        .clipShape(Capsule())
                    }
                }
            }
            .frame(maxWidth: 680, alignment: .leading)
            .padding(.leading, contentLeadingInset)
            .padding(.trailing, 40)
            .padding(.bottom, 104)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
