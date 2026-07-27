import Foundation

// MARK: - Movie

struct MovieDTO: Codable, Identifiable, Hashable {
    let title: String
    let year: Int?
    let ids: MovieIds
    let images: ImagesDTO?
    let overview: String?
    let rating: Double?
    let votes: Int?
    let genres: [String]?
    let runtime: Int?
    let released: String?
    let trailer: String?
    let tagline: String?
    let watchers: Int?

    var id: Int { ids.trakt }
}

struct MovieIds: Codable, Hashable {
    let trakt: Int
    let slug: String?
    let imdb: String?
    let tmdb: Int?
    let tvdb: Int?
}

struct ImagesDTO: Codable, Hashable {
    let poster: [String]?
    let fanart: [String]?
    let banner: [String]?
    let thumb: [String]?
    let logo: [String]?
    let clearart: [String]?
    let screenshot: [String]?

    var bestPosterURL: String? {
        poster?.first ?? fanart?.first ?? thumb?.first ?? banner?.first ?? screenshot?.first
    }
}

// MARK: - Movie Details

struct MovieDetailsDTO: Codable, Identifiable {
    let title: String
    let year: Int
    let ids: MovieIds
    let tagline: String?
    let overview: String?
    let released: String?
    let runtime: Int?
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
    let certification: String?
    let originalTitle: String?
    let images: ImagesDTO?

    var id: Int { ids.trakt }

    enum CodingKeys: String, CodingKey {
        case title, year, ids, tagline, overview, released, runtime, country
        case updatedAt = "updated_at"
        case trailer, homepage, status, rating, votes
        case commentCount = "comment_count"
        case languages
        case availableTranslations = "available_translations"
        case genres, certification
        case originalTitle = "original_title"
        case images
    }
}

// MARK: - Movie Trending

struct MovieTrendingDTO: Codable, Identifiable {
    let watchers: Int?
    let movie: MovieDTO

    var id: Int { movie.ids.trakt }
}

// MARK: - Movie Anticipated

struct MovieAnticipatedDTO: Codable, Identifiable {
    let listCount: Int
    let movie: MovieDTO

    var id: Int { movie.ids.trakt }

    enum CodingKeys: String, CodingKey {
        case listCount = "list_count"
        case movie
    }
}

// MARK: - Movie Translation

struct MovieTranslationDTO: Codable {
    let title: String
    let overview: String
    let tagline: String?
    let language: String
    let country: String
}

// MARK: - Movie Watched/Collected

struct MovieWatchedDTO: Codable, Identifiable {
    let watcherCount: Int
    let playCount: Int
    let collectedCount: Int
    let movie: MovieDTO

    var id: Int { movie.ids.trakt }

    enum CodingKeys: String, CodingKey {
        case watcherCount = "watcher_count"
        case playCount = "play_count"
        case collectedCount = "collected_count"
        case movie
    }
}

struct MovieCollectedDTO: Codable, Identifiable {
    let collectedCount: Int
    let movie: MovieDTO

    var id: Int { movie.ids.trakt }

    enum CodingKeys: String, CodingKey {
        case collectedCount = "collected_count"
        case movie
    }
}
