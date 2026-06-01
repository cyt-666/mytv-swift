import SwiftUI

struct AsyncPosterImage: View {
    let urlString: String?
    @State private var image: NSImage?
    @State private var isLoading = false

    var body: some View {
        Group {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else if isLoading {
                Rectangle()
                    .fill(.quaternary)
                    .overlay {
                        ProgressView()
                            .scaleEffect(0.6)
                    }
            } else {
                Rectangle()
                    .fill(.quaternary)
                    .overlay {
                        Image(systemName: "photo")
                            .font(.title2)
                            .foregroundStyle(.tertiary)
                    }
            }
        }
        .task(id: urlString) { await loadImage() }
    }

    private func loadImage() async {
        guard let urlString, !urlString.isEmpty else { return }
        let fullURL = urlString.hasPrefix("http") ? urlString : "https://\(urlString)"
        guard let url = URL(string: fullURL) else { return }

        // Check cache
        if let cached = await ImageService.shared.getCached(for: url) {
            self.image = cached
            return
        }

        isLoading = true
        self.image = await ImageService.shared.load(url: url)
        isLoading = false
    }
}
