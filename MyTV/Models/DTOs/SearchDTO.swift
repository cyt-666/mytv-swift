import Foundation

struct SearchResultDTO: Codable, Identifiable {
    let type: String
    let score: Double?
    let movie: MovieDTO?
    let show: ShowDTO?

    var id: Int {
        switch type {
        case "movie": return movie?.ids.trakt ?? 0
        case "show": return show?.ids.trakt ?? 0
        default: return 0
        }
    }
}

struct SyncDTO: Codable {
    let added: SyncCountsDTO?
    let removed: SyncCountsDTO?
    let notFound: SyncNotFoundDTO?

    enum CodingKeys: String, CodingKey {
        case added, removed
        case notFound = "not_found"
    }
}

struct SyncCountsDTO: Codable {
    let movies: Int?
    let shows: Int?
    let seasons: Int?
    let episodes: Int?
}

struct SyncNotFoundDTO: Codable {
    let movies: [SyncNotFoundItemDTO]?
    let shows: [SyncNotFoundItemDTO]?
}

struct SyncNotFoundItemDTO: Codable {
    let ids: MovieIds?
}
