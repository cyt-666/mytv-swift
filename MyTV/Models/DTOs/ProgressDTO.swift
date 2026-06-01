import Foundation

struct ShowProgressDTO: Codable {
    let aired: Int
    let completed: Int
    let lastWatchedAt: String?
    let resetAt: String?
    let nextEpisode: EpisodeDTO?
    let lastEpisode: EpisodeDTO?

    enum CodingKeys: String, CodingKey {
        case aired, completed
        case lastWatchedAt = "last_watched_at"
        case resetAt = "reset_at"
        case nextEpisode = "next_episode"
        case lastEpisode = "last_episode"
    }
}

struct UpNextItemDTO: Codable, Identifiable {
    let show: ShowDTO
    let nextEpisode: EpisodeDTO
    let progress: ShowProgressSummaryDTO

    var id: String { "\(show.ids.trakt)_\(nextEpisode.season)_\(nextEpisode.number)" }
}

struct ShowProgressSummaryDTO: Codable {
    let aired: Int
    let completed: Int
    let lastWatchedAt: String?

    enum CodingKeys: String, CodingKey {
        case aired, completed
        case lastWatchedAt = "last_watched_at"
    }
}
