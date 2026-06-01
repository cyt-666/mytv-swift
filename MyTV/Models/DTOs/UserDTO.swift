import Foundation

struct UserProfileDTO: Codable {
    let user: UserDTO
    let account: AccountDTO?
    let connections: ConnectionsDTO?
    let sharingText: SharingTextDTO?

    enum CodingKeys: String, CodingKey {
        case user, account, connections
        case sharingText = "sharing_text"
    }
}

struct UserDTO: Codable, Identifiable, Hashable {
    let username: String
    let isPrivate: Bool
    let name: String?
    let isVIP: Bool
    let isVIPEP: Bool
    let ids: UserIds
    let description: String?
    let email: String?
    let location: String?
    let website: String?
    let twitter: String?
    let joinedAt: String?
    let lastLoginAt: String?
    let images: UserImagesDTO?

    var id: String { ids.slug }

    enum CodingKeys: String, CodingKey {
        case username, name, ids, description, email, location, website, twitter, images
        case isPrivate = "private"
        case isVIP = "vip"
        case isVIPEP = "vip_ep"
        case joinedAt = "joined_at"
        case lastLoginAt = "last_login_at"
    }
}

struct UserIds: Codable, Hashable {
    let slug: String
    let uuid: String?
}

struct UserImagesDTO: Codable, Hashable {
    let avatar: AvatarDTO?
}

struct AvatarDTO: Codable, Hashable {
    let full: String?
}

struct AccountDTO: Codable {
    let timezone: String?
    let dateFormat: String?
    let time24hr: Bool?

    enum CodingKeys: String, CodingKey {
        case timezone
        case dateFormat = "date_format"
        case time24hr = "time_24hr"
    }
}

struct ConnectionsDTO: Codable {
    let facebook: Bool?
    let twitter: Bool?
    let google: Bool?
    let tumblr: Bool?
    let medium: Bool?
    let slack: Bool?
}

struct SharingTextDTO: Codable {
    let watching: String?
    let watched: String?
}

// MARK: - User Stats

struct UserStatsDTO: Codable {
    let movies: MovieStatsDTO
    let shows: ShowStatsDTO
    let seasons: SeasonStatsDTO
    let episodes: EpisodeStatsDTO
    let network: NetworkStatsDTO
    let ratings: RatingsStatsDTO
}

struct MovieStatsDTO: Codable {
    let plays: Int
    let watched: Int
    let minutes: Int
    let collected: Int
    let ratings: Int
    let comments: Int
}

struct ShowStatsDTO: Codable {
    let watched: Int
    let collected: Int
    let ratings: Int
    let comments: Int
}

struct SeasonStatsDTO: Codable {
    let ratings: Int
    let comments: Int
}

struct EpisodeStatsDTO: Codable {
    let plays: Int
    let watched: Int
    let minutes: Int
    let collected: Int
    let ratings: Int
    let comments: Int
}

struct NetworkStatsDTO: Codable {
    let friends: Int
    let followers: Int
    let following: Int
}

struct RatingsStatsDTO: Codable {
    let total: Int
    let distribution: [String: Int]
}
