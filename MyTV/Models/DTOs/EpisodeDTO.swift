import Foundation

struct EpisodeDTO: Codable, Identifiable, Hashable {
    let season: Int
    let number: Int
    let title: String?
    let ids: EpisodeIds
    let overview: String?
    let rating: Double?
    let votes: Int?
    let runtime: Int?
    let firstAired: String?
    let images: ImagesDTO?

    var id: Int { ids.trakt }

    enum CodingKeys: String, CodingKey {
        case season, number, title, ids, overview, rating, votes, runtime, images
        case firstAired = "first_aired"
    }
}

struct EpisodeIds: Codable, Hashable {
    let trakt: Int
    let tvdb: Int?
    let tmdb: Int?
    let imdb: String?
}

struct EpisodeTranslationDTO: Codable {
    let title: String?
    let overview: String?
    let language: String?
    let country: String?
}
