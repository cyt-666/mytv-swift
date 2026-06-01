import Foundation

@Observable
@MainActor
final class CollectionViewModel {
    var mediaType = "movies"
    var items: [MediaItem] = []
    var isLoading = false

    func load() async {
        isLoading = true
        defer { isLoading = false }

        do {
            if mediaType == "movies" {
                let result: [CollectionMovieDTO] = try await TraktAPIClient.shared.request(
                    uri: "/users/me/collection/movies",
                    params: ["extended": "full,images"],
                    requiresAuth: true
                )
                items = result.map { .movie($0.movie) }
            } else {
                let result: [CollectionShowDTO] = try await TraktAPIClient.shared.request(
                    uri: "/users/me/collection/shows",
                    params: ["extended": "full,images"],
                    requiresAuth: true
                )
                items = result.map { .show($0.show) }
            }
        } catch {
            print("加载片库失败: \(error)")
        }
    }
}

struct CollectionMovieDTO: Codable, Identifiable {
    let collectedAt: String
    let movie: MovieDTO
    var id: Int { movie.ids.trakt }
    enum CodingKeys: String, CodingKey { case collectedAt = "collected_at"; case movie }
}

struct CollectionShowDTO: Codable, Identifiable {
    let collectedAt: String
    let show: ShowDTO
    var id: Int { show.ids.trakt }
    enum CodingKeys: String, CodingKey { case collectedAt = "collected_at"; case show }
}
