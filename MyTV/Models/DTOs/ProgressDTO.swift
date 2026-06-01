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

    var displayCompletedEpisodes: Int {
        var corrected = progress.displayCompleted

        // Old cached records may not have the inferred count yet. If Trakt says
        // the next unwatched episode is S1E3, the UI should never show fewer
        // than two watched episodes.
        if nextEpisode.season == 1 {
            corrected = max(corrected, max(nextEpisode.number - 1, 0))
        }

        return min(corrected, max(progress.aired, corrected, 1))
    }

    var displayAiredEpisodes: Int {
        max(progress.aired, displayCompletedEpisodes, 1)
    }
}

struct ShowProgressSummaryDTO: Codable {
    let aired: Int
    let completed: Int
    let inferredCompleted: Int?
    let lastWatchedAt: String?

    var displayCompleted: Int {
        let corrected = max(completed, inferredCompleted ?? completed)
        return min(max(corrected, 0), max(aired, 1))
    }

    enum CodingKeys: String, CodingKey {
        case aired, completed
        case inferredCompleted = "inferred_completed"
        case lastWatchedAt = "last_watched_at"
    }
}
