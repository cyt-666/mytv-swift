import Foundation

// MARK: - Show

struct ShowDTO: Codable, Identifiable, Hashable {
    let title: String
    let year: Int?
    let ids: ShowIds
    let images: ImagesDTO?
    let overview: String?
    let rating: Double?
    let votes: Int?
    let genres: [String]?
    let runtime: Int?
    let released: String?
    let trailer: String?
    let watchers: Int?
    let status: String?
    let network: String?
    let country: String?
    let language: String?
    let airedEpisodes: Int?
    let totalEpisodes: Int?
    let seasons: Int?

    var id: Int { ids.trakt }

    enum CodingKeys: String, CodingKey {
        case title, year, ids, images, overview, rating, votes, genres, runtime
        case released, trailer, watchers, status, network, country, language
        case airedEpisodes = "aired_episodes"
        case totalEpisodes = "total_episodes"
        case seasons
    }
}

struct ShowIds: Codable, Hashable {
    let trakt: Int
    let slug: String?
    let tvdb: Int?
    let imdb: String?
    let tmdb: Int?
    let tvrage: Int?
}

// MARK: - Show Details

struct ShowDetailsDTO: Codable, Identifiable {
    let title: String
    let year: Int
    let ids: ShowIds
    let tagline: String?
    let overview: String?
    let firstAired: String?
    let airs: AirsDTO?
    let runtime: Int?
    let certification: String?
    let network: String?
    let country: String?
    let updatedAt: String?
    let trailer: String?
    let homepage: String?
    let status: String?
    let rating: Double?
    let votes: Int?
    let commentCount: Int?
    let languages: [String]?
    let availableTranslations: [String]?
    let genres: [String]?
    let airedEpisodes: Int?
    let originalTitle: String?
    let images: ImagesDTO?

    var id: Int { ids.trakt }

    enum CodingKeys: String, CodingKey {
        case title, year, ids, tagline, overview
        case firstAired = "first_aired"
        case airs, runtime, certification, network, country
        case updatedAt = "updated_at"
        case trailer, homepage, status, rating, votes
        case commentCount = "comment_count"
        case languages
        case availableTranslations = "available_translations"
        case genres
        case airedEpisodes = "aired_episodes"
        case originalTitle = "original_title"
        case images
    }
}

struct AirsDTO: Codable, Hashable {
    let day: String?
    let time: String?
    let timezone: String?
}

// MARK: - Show Trending

struct ShowTrendingDTO: Codable, Identifiable {
    let watchers: Int?
    let show: ShowDTO

    var id: Int { show.ids.trakt }
}

// MARK: - Show Anticipated

struct ShowAnticipatedDTO: Codable, Identifiable {
    let listCount: Int
    let show: ShowDTO

    var id: Int { show.ids.trakt }

    enum CodingKeys: String, CodingKey {
        case listCount = "list_count"
        case show
    }
}

// MARK: - Show Translation

struct ShowTranslationDTO: Codable {
    let title: String
    let overview: String
    let tagline: String?
    let language: String
    let country: String
}

// MARK: - Show Watched/Collected

struct ShowWatchedDTO: Codable, Identifiable {
    let watcherCount: Int
    let playCount: Int
    let collectedCount: Int
    let show: ShowDTO

    var id: Int { show.ids.trakt }

    enum CodingKeys: String, CodingKey {
        case watcherCount = "watcher_count"
        case playCount = "play_count"
        case collectedCount = "collected_count"
        case show
    }
}

struct ShowCollectedDTO: Codable, Identifiable {
    let collectedCount: Int
    let show: ShowDTO

    var id: Int { show.ids.trakt }

    enum CodingKeys: String, CodingKey {
        case collectedCount = "collected_count"
        case show
    }
}
