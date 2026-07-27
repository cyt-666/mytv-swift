import Foundation

enum MoviePilotMediaKind: String, Codable, Sendable {
    case movie
    case tv

    var displayName: String {
        switch self {
        case .movie: return L10n.string("电影")
        case .tv: return L10n.string("电视剧")
        }
    }
}

enum MoviePilotSubscriptionKind: String, CaseIterable, Identifiable, Sendable {
    case movie = "电影订阅"
    case tv = "电视剧订阅"

    var id: String { rawValue }

    var mediaKind: MoviePilotMediaKind {
        switch self {
        case .movie: return .movie
        case .tv: return .tv
        }
    }

    var emptyTitle: String {
        switch self {
        case .movie: return L10n.string("暂无电影订阅")
        case .tv: return L10n.string("暂无电视剧订阅")
        }
    }

    var segmentTitle: String {
        switch self {
        case .movie: return L10n.string("电影")
        case .tv: return L10n.string("剧集")
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

    static let requiredTools: Set<String> = [
        "query_library_exists",
        "query_download_tasks"
    ]

    var hasRequiredTools: Bool {
        Self.requiredTools.isSubset(of: availableTools)
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

struct MoviePilotRESTResponse: Decodable, Sendable {
    let success: Bool
    let message: String?
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
    let tmdbId: Int?
    let doubanId: String?
    let bangumiId: Int?
    let mediaId: String?
    let season: Int?
    let totalEpisode: Int?
    let startEpisode: Int?
    let lackEpisode: Int?
    let state: String?
    let lastUpdate: String?

    var isRunning: Bool { state == "R" }
    var isPaused: Bool { state == "S" }

    var mediaKind: MoviePilotMediaKind? {
        switch type?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "movie", "电影":
            return .movie
        case "tv", "show", "电视剧":
            return .tv
        default:
            return nil
        }
    }

    var displayTitle: String {
        let fallback = "订阅 #\(id)"
        guard let base = name?.trimmingCharacters(in: .whitespacesAndNewlines),
              !base.isEmpty else {
            return fallback
        }
        return base
    }

    var displaySubtitle: String {
        var parts: [String] = []
        if let year, !year.isEmpty {
            parts.append(year)
        }
        if type == "电视剧" || type == "tv", let season {
            parts.append("S\(season)")
        } else if let type, !type.isEmpty {
            parts.append(type)
        }
        if let lackEpisode {
            parts.append(L10n.string("缺失 %d", lackEpisode))
        }
        return parts.isEmpty ? L10n.string("MoviePilot 订阅") : parts.joined(separator: " · ")
    }

    var stateLabel: String {
        switch state {
        case "R": return L10n.string("订阅中")
        case "S": return L10n.string("已暂停")
        case "P": return L10n.string("待定")
        case "N": return L10n.string("新建")
        case let value? where !value.isEmpty: return value
        default: return L10n.string("未知")
        }
    }

    var restMediaIdentifier: String? {
        if let tmdbId {
            return "tmdb:\(tmdbId)"
        }
        if let doubanId = doubanId?.trimmingCharacters(in: .whitespacesAndNewlines),
           !doubanId.isEmpty {
            return "douban:\(doubanId)"
        }
        if let mediaId = mediaId?.trimmingCharacters(in: .whitespacesAndNewlines),
           !mediaId.isEmpty {
            return mediaId
        }
        return nil
    }

    enum CodingKeys: String, CodingKey {
        case id, name, year, type, season, state
        case tmdbId = "tmdbid"
        case doubanId = "doubanid"
        case bangumiId = "bangumiid"
        case mediaId = "mediaid"
        case totalEpisode = "total_episode"
        case startEpisode = "start_episode"
        case lackEpisode = "lack_episode"
        case lastUpdate = "last_update"
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

    var displayTitle: String {
        let candidates = [title, media?.title, name]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
        return candidates.first { !$0.isEmpty } ?? L10n.string("下载任务")
    }

    var displaySubtitle: String {
        var parts: [String] = []
        if let year, !year.isEmpty {
            parts.append(year)
        }
        if let seasonEpisode, !seasonEpisode.isEmpty {
            parts.append(seasonEpisode)
        }
        if let downloader, !downloader.isEmpty {
            parts.append(downloader)
        }
        return parts.isEmpty ? L10n.string("MoviePilot 下载") : parts.joined(separator: " · ")
    }

    var stateLabel: String {
        guard let state, !state.isEmpty else { return L10n.string("未知") }
        switch state.lowercased() {
        case "downloading": return L10n.string("下载中")
        case "paused": return L10n.string("已暂停")
        case "seeding": return L10n.string("做种中")
        case "completed": return L10n.string("已完成")
        case "stalleddl": return L10n.string("等待下载")
        case "stalledup": return L10n.string("等待做种")
        default: return state
        }
    }

    var isPaused: Bool {
        guard let state else { return false }
        return state.lowercased().contains("paused")
    }

    var isCompleted: Bool {
        guard let state else { return false }
        return ["seeding", "completed"].contains(state.lowercased())
    }

    var canModify: Bool {
        hash?.isEmpty == false && !isCompleted
    }

    var canDelete: Bool {
        hash?.isEmpty == false
    }

    enum CodingKeys: String, CodingKey {
        case downloader, hash, title, name, year, size, progress, state, upspeed, dlspeed, tags, media
        case seasonEpisode = "season_episode"
        case leftTime = "left_time"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        downloader = try container.decodeIfPresent(String.self, forKey: .downloader)
        hash = try container.decodeIfPresent(String.self, forKey: .hash)
        title = try container.decodeIfPresent(String.self, forKey: .title)
        name = try container.decodeIfPresent(String.self, forKey: .name)
        year = try container.decodeIfPresent(String.self, forKey: .year)
        seasonEpisode = try container.decodeIfPresent(String.self, forKey: .seasonEpisode)
        size = try container.decodeIfPresent(Double.self, forKey: .size)
        progress = try Self.decodeStringOrNumber(from: container, forKey: .progress)
        state = try container.decodeIfPresent(String.self, forKey: .state)
        upspeed = try container.decodeIfPresent(String.self, forKey: .upspeed)
        dlspeed = try container.decodeIfPresent(String.self, forKey: .dlspeed)
        tags = try container.decodeIfPresent(String.self, forKey: .tags)
        leftTime = try container.decodeIfPresent(String.self, forKey: .leftTime)
        media = try container.decodeIfPresent(MoviePilotDownloadMedia.self, forKey: .media)
    }

    private static func decodeStringOrNumber(
        from container: KeyedDecodingContainer<CodingKeys>,
        forKey key: CodingKeys
    ) throws -> String? {
        if let stringValue = try? container.decodeIfPresent(String.self, forKey: key) {
            return stringValue
        }
        if let doubleValue = try? container.decodeIfPresent(Double.self, forKey: key) {
            return String(format: "%.1f%%", doubleValue)
        }
        return nil
    }
}

struct MoviePilotDownloadMedia: Decodable, Sendable {
    let tmdbid: Int?
    let type: String?
    let title: String?
    let season: String?
    let episode: String?
    let image: String?
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

enum MoviePilotMessageTextFormatter {
    private static let markdownLinkRegex = try? NSRegularExpression(pattern: #"\[([^\]]+)\]\(([^)]+)\)"#)

    static func cleaned(_ value: String?) -> String? {
        guard let value else { return nil }

        let withNewlines = value.replacingOccurrences(of: "\\n", with: "\n")
        guard let regex = markdownLinkRegex else {
            return nonEmpty(withNewlines)
        }

        let nsValue = withNewlines as NSString
        let range = NSRange(location: 0, length: nsValue.length)
        let withoutMarkdownLinks = regex.stringByReplacingMatches(
            in: withNewlines,
            range: range,
            withTemplate: "$1"
        )

        let normalizedLines = withoutMarkdownLinks
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .joined(separator: "\n")

        return nonEmpty(normalizedLines)
    }

    private static func nonEmpty(_ value: String?) -> String? {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed?.isEmpty == false ? trimmed : nil
    }
}

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

enum MoviePilotNotificationCategory: String, Codable, CaseIterable, Identifiable, Sendable {
    case organize
    case download
    case subscribe
    case exception

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .organize: return L10n.string("入库")
        case .download: return L10n.string("下载")
        case .subscribe: return L10n.string("订阅")
        case .exception: return L10n.string("异常")
        }
    }

    var systemImage: String {
        switch self {
        case .organize: return "externaldrive.fill"
        case .download: return "arrow.down.circle.fill"
        case .subscribe: return "checkmark.seal.fill"
        case .exception: return "exclamationmark.triangle.fill"
        }
    }

    var settingsDescription: String {
        switch self {
        case .organize: return L10n.string("整理入库完成或相关入库消息")
        case .download: return L10n.string("添加、删除或完成下载任务")
        case .subscribe: return L10n.string("订阅添加、调整、删除或完成")
        case .exception: return L10n.string("失败、错误、异常或手动处理消息")
        }
    }

    static let defaultEnabled: Set<MoviePilotNotificationCategory> = Set(allCases)

    static func category(for message: MoviePilotMessage) -> MoviePilotNotificationCategory? {
        let values = [message.mtype, message.title, message.text]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
        let haystack = values.joined(separator: " ").lowercased()

        if ["失败", "错误", "异常", "手动处理", "failed", "error"].contains(where: { haystack.contains($0) }) {
            return .exception
        }

        switch message.mtype {
        case "整理入库":
            return .organize
        case "资源下载":
            return .download
        case "订阅":
            return .subscribe
        case "手动处理", "其它":
            return .exception
        default:
            return nil
        }
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
