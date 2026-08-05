import SwiftUI

struct AsyncShowPosterImage: View {
    let show: ShowDTO
    var contentMode: ContentMode = .fill

    @State private var fallbackURL: String?

    private var resolvedURL: String? {
        show.images?.preferredPosterURL ?? fallbackURL
    }

    var body: some View {
        AsyncPosterImage(urlString: resolvedURL, contentMode: contentMode)
            .task(id: show.ids.trakt) {
                await loadFallbackArtwork()
            }
    }

    private func loadFallbackArtwork() async {
        fallbackURL = nil
        guard show.images?.preferredPosterURL == nil else { return }

        guard let details = try? await ShowAPI.details(id: show.ids.trakt),
              !Task.isCancelled else {
            return
        }
        fallbackURL = details.images?.preferredPosterURL
    }
}
