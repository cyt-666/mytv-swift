import Foundation

struct SeasonDTO: Codable, Identifiable, Hashable {
    let number: Int
    let ids: SeasonIds
    let rating: Double?
    let votes: Int?
    let episodeCount: Int?
    let airedEpisodes: Int?
    let title: String?
    let overview: String?
    let firstAired: String?
    let updatedAt: String?
    let network: String?
    let originalTitle: String?
    let images: ImagesDTO?

    var id: Int { number }

    enum CodingKeys: String, CodingKey {
        case number, ids, rating, votes, title, overview, network, images
        case episodeCount = "episode_count"
        case airedEpisodes = "aired_episodes"
        case firstAired = "first_aired"
        case updatedAt = "updated_at"
        case originalTitle = "original_title"
    }
}

struct SeasonIds: Codable, Hashable {
    let trakt: Int
    let tvdb: Int?
    let tmdb: Int?
}

struct SeasonTranslationDTO: Codable {
    let title: String?
    let overview: String?
    let language: String?
    let country: String?
}
