import Foundation

enum MoviePilotMediaKind: String, Codable, Sendable {
    case movie
    case tv

    var displayName: String {
        switch self {
        case .movie: return "电影"
        case .tv: return "电视剧"
        }
    }
}

struct MoviePilotMediaTarget: Hashable, Sendable {
    let kind: MoviePilotMediaKind
    let title: String
    let year: Int?
    let tmdbId: Int?
    let traktId: Int

    var yearString: String {
        year.map(String.init) ?? ""
    }
}

struct MoviePilotTool: Decodable, Sendable {
    let name: String
    let description: String?
}

struct MoviePilotConnectionResult: Equatable, Sendable {
    let isConnected: Bool
    let availableTools: Set<String>

    var hasRequiredTools: Bool {
        let required: Set<String> = [
            "add_subscribe",
            "query_subscribes",
            "query_library_exists",
            "query_download_tasks"
        ]
        return required.isSubset(of: availableTools)
    }
}

struct MoviePilotToolCallRequest: Encodable, Sendable {
    let toolName: String
    let arguments: [String: MoviePilotJSONValue]

    enum CodingKeys: String, CodingKey {
        case toolName = "tool_name"
        case arguments
    }
}

struct MoviePilotToolCallResponse: Decodable, Sendable {
    let success: Bool
    let result: String?
    let error: String?
}

enum MoviePilotJSONValue: Encodable, Sendable {
    case string(String)
    case int(Int)
    case bool(Bool)
    case stringArray([String])
    case intArray([Int])

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value):
            try container.encode(value)
        case .int(let value):
            try container.encode(value)
        case .bool(let value):
            try container.encode(value)
        case .stringArray(let value):
            try container.encode(value)
        case .intArray(let value):
            try container.encode(value)
        }
    }
}

struct MoviePilotSubscription: Decodable, Identifiable, Sendable {
    let id: Int
    let name: String?
    let year: String?
    let type: String?
    let season: Int?
    let totalEpisode: Int?
    let startEpisode: Int?
    let lackEpisode: Int?
    let state: String?

    var isRunning: Bool { state == "R" }

    enum CodingKeys: String, CodingKey {
        case id, name, year, type, season, state
        case totalEpisode = "total_episode"
        case startEpisode = "start_episode"
        case lackEpisode = "lack_episode"
    }
}

struct MoviePilotLibraryLookupItem: Decodable, Sendable {
    let title: String?
    let year: String?
    let type: String?
    let servers: [String: MoviePilotLibraryServer]
}

struct MoviePilotLibraryServer: Decodable, Sendable {
    let exists: Bool?
    let seasons: [String: MoviePilotLibrarySeason]?
    let missingSeasons: [Int]?

    enum CodingKeys: String, CodingKey {
        case exists, seasons
        case missingSeasons = "missing_seasons"
    }
}

struct MoviePilotLibrarySeason: Decodable, Sendable {
    let existingEpisodes: [Int]
    let totalEpisodes: Int?
    let missingEpisodes: [Int]?

    enum CodingKeys: String, CodingKey {
        case existingEpisodes = "existing_episodes"
        case totalEpisodes = "total_episodes"
        case missingEpisodes = "missing_episodes"
    }
}

struct MoviePilotDownloadTask: Decodable, Identifiable, Sendable {
    let downloader: String?
    let hash: String?
    let title: String?
    let name: String?
    let year: String?
    let seasonEpisode: String?
    let size: Double?
    let progress: String?
    let state: String?
    let upspeed: String?
    let dlspeed: String?
    let tags: String?
    let leftTime: String?
    let media: MoviePilotDownloadMedia?

    var id: String {
        hash ?? [title, name, seasonEpisode, state].compactMap { $0 }.joined(separator: "|")
    }

    enum CodingKeys: String, CodingKey {
        case downloader, hash, title, name, year, size, progress, state, upspeed, dlspeed, tags, media
        case seasonEpisode = "season_episode"
        case leftTime = "left_time"
    }
}

struct MoviePilotDownloadMedia: Decodable, Sendable {
    let tmdbid: Int?
    let type: String?
    let title: String?
    let season: String?
    let episode: String?
}

struct MoviePilotMediaStatus: Equatable, Sendable {
    var subscriptions: [MoviePilotSubscription] = []
    var libraryItems: [MoviePilotLibraryLookupItem] = []
    var downloads: [MoviePilotDownloadTask] = []

    static let empty = MoviePilotMediaStatus()

    var hasSubscription: Bool {
        !subscriptions.isEmpty
    }

    var hasLibraryItem: Bool {
        libraryItems.contains { item in
            item.servers.values.contains { server in
                if server.exists == true {
                    return true
                }
                return server.seasons?.values.contains { !$0.existingEpisodes.isEmpty } == true
            }
        }
    }

    var activeDownloadCount: Int {
        downloads.filter { task in
            guard let state = task.state?.lowercased() else { return true }
            return !["seeding", "completed"].contains(state)
        }.count
    }

    func isSeasonSubscribed(_ season: Int) -> Bool {
        subscriptions.contains { $0.season == season }
    }
}

extension MoviePilotSubscription: Equatable {}
extension MoviePilotLibraryLookupItem: Equatable {}
extension MoviePilotLibraryServer: Equatable {}
extension MoviePilotLibrarySeason: Equatable {}
extension MoviePilotDownloadTask: Equatable {}
extension MoviePilotDownloadMedia: Equatable {}

struct MoviePilotMessage: Decodable, Identifiable, Sendable {
    let id: Int
    let channel: String?
    let source: String?
    let mtype: String?
    let title: String?
    let text: String?
    let image: String?
    let link: String?
    let userId: String?
    let regTime: String?
    let action: Int?

    enum CodingKeys: String, CodingKey {
        case id, channel, source, mtype, title, text, image, link, action
        case userId = "userid"
        case regTime = "reg_time"
    }
}

extension MoviePilotMediaTarget {
    static func movie(_ movie: MovieDetailsDTO) -> MoviePilotMediaTarget {
        MoviePilotMediaTarget(
            kind: .movie,
            title: movie.title,
            year: movie.year,
            tmdbId: movie.ids.tmdb,
            traktId: movie.ids.trakt
        )
    }

    static func show(_ show: ShowDetailsDTO) -> MoviePilotMediaTarget {
        MoviePilotMediaTarget(
            kind: .tv,
            title: show.title,
            year: show.year,
            tmdbId: show.ids.tmdb,
            traktId: show.ids.trakt
        )
    }
}
