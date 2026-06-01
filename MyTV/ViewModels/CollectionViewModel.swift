import Foundation

@Observable
@MainActor
final class CollectionViewModel {
    var mediaType = "movies"
    private var movieItems: [MovieDTO] = []
    private var showItems: [ShowDTO] = []
    private var loadingMediaTypes = Set<String>()

    var items: [MediaItem] {
        if mediaType == "movies" {
            return movieItems.map { .movie($0) }
        }
        return showItems.map { .show($0) }
    }

    var isLoading: Bool {
        loadingMediaTypes.contains(mediaType)
    }

    func load() async {
        let targetType = mediaType
        loadingMediaTypes.insert(targetType)
        defer { loadingMediaTypes.remove(targetType) }

        do {
            if targetType == "movies" {
                let result: [CollectionMovieDTO] = try await TraktAPIClient.shared.request(
                    uri: "/users/me/collection/movies",
                    params: ["extended": "full,images"],
                    requiresAuth: true
                )
                movieItems = result.map(\.movie)
            } else {
                let result: [CollectionShowDTO] = try await TraktAPIClient.shared.request(
                    uri: "/users/me/collection/shows",
                    params: ["extended": "full,images"],
                    requiresAuth: true
                )
                showItems = result.map(\.show)
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
    let lastCollectedAt: String?
    let lastUpdatedAt: String?
    let show: ShowDTO
    var id: Int { show.ids.trakt }
    enum CodingKeys: String, CodingKey {
        case lastCollectedAt = "last_collected_at"
        case lastUpdatedAt = "last_updated_at"
        case show
    }
}
