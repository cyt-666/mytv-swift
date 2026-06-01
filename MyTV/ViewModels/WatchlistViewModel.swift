import Foundation

@Observable
@MainActor
final class WatchlistViewModel {
    var mediaType = "movies"
    var items: [MediaItem] = []
    var isLoading = false

    func load() async {
        isLoading = true
        defer { isLoading = false }

        do {
            if mediaType == "movies" {
                let result: [WatchlistMovieDTO] = try await TraktAPIClient.shared.request(
                    uri: "/users/me/watchlist/movies",
                    params: ["extended": "full,images"],
                    requiresAuth: true
                )
                items = result.map { .movie($0.movie) }
            } else {
                let result: [WatchlistShowDTO] = try await TraktAPIClient.shared.request(
                    uri: "/users/me/watchlist/shows",
                    params: ["extended": "full,images"],
                    requiresAuth: true
                )
                items = result.map { .show($0.show) }
            }
        } catch {
            print("加载观看清单失败: \(error)")
        }
    }
}

struct WatchlistMovieDTO: Codable, Identifiable {
    let listedAt: String
    let movie: MovieDTO
    var id: Int { movie.ids.trakt }
    enum CodingKeys: String, CodingKey { case listedAt = "listed_at"; case movie }
}
