import Foundation

struct MoviePilotSearchSite: Codable, Hashable, Sendable {
    let id: Int?
    let name: String?
}

struct MoviePilotSearchFilterOptions: Codable, Equatable, Sendable {
    let site: [String]
    let season: [String]
    let freeState: [String]
    let edition: [String]
    let resolution: [String]
    let videoCode: [String]
    let releaseGroup: [String]

    static let empty = MoviePilotSearchFilterOptions(
        site: [],
        season: [],
        freeState: [],
        edition: [],
        resolution: [],
        videoCode: [],
        releaseGroup: []
    )

    private enum CodingKeys: String, CodingKey {
        case site, season, edition, resolution
        case freeState
        case videoCode
        case releaseGroup
    }

    init(
        site: [String],
        season: [String],
        freeState: [String],
        edition: [String],
        resolution: [String],
        videoCode: [String],
        releaseGroup: [String]
    ) {
        self.site = site
        self.season = season
        self.freeState = freeState
        self.edition = edition
        self.resolution = resolution
        self.videoCode = videoCode
        self.releaseGroup = releaseGroup
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        site = try container.decodeIfPresent([String].self, forKey: .site) ?? []
        season = try container.decodeIfPresent([String].self, forKey: .season) ?? []
        freeState = try container.decodeIfPresent([String].self, forKey: .freeState) ?? []
        edition = try container.decodeIfPresent([String].self, forKey: .edition) ?? []
        resolution = try container.decodeIfPresent([String].self, forKey: .resolution) ?? []
        videoCode = try container.decodeIfPresent([String].self, forKey: .videoCode) ?? []
        releaseGroup = try container.decodeIfPresent([String].self, forKey: .releaseGroup) ?? []
    }
}

struct MoviePilotTorrentSearchSummary: Codable, Sendable {
    let totalCount: Int?
    let message: String?
    let allSites: [MoviePilotSearchSite]
    let searchSiteIds: [Int]
    let filterOptions: MoviePilotSearchFilterOptions

    private enum CodingKeys: String, CodingKey {
        case message
        case totalCount = "total_count"
        case allSites = "all_sites"
        case searchSiteIds = "search_site_ids"
        case filterOptions = "filter_options"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        totalCount = try container.decodeIfPresent(Int.self, forKey: .totalCount)
        message = try container.decodeIfPresent(String.self, forKey: .message)
        allSites = try container.decodeIfPresent([MoviePilotSearchSite].self, forKey: .allSites) ?? []
        searchSiteIds = try container.decodeIfPresent([Int].self, forKey: .searchSiteIds) ?? []
        filterOptions = try container.decodeIfPresent(
            MoviePilotSearchFilterOptions.self,
            forKey: .filterOptions
        ) ?? .empty
    }
}

struct MoviePilotTorrentSearchPage: Codable, Sendable {
    let totalCount: Int
    let page: Int
    let totalPages: Int
    let results: [MoviePilotTorrentSearchResult]
    let message: String?

    static func empty(page: Int = 1) -> MoviePilotTorrentSearchPage {
        MoviePilotTorrentSearchPage(
            totalCount: 0,
            page: page,
            totalPages: 0,
            results: [],
            message: nil
        )
    }

    private enum CodingKeys: String, CodingKey {
        case page, results, message
        case totalCount = "total_count"
        case totalPages = "total_pages"
    }
}

struct MoviePilotTorrentSearchResult: Codable, Identifiable, Sendable {
    let torrentInfo: MoviePilotTorrentInfo?
    let mediaInfo: MoviePilotTorrentMediaInfo?
    let metaInfo: MoviePilotTorrentMetaInfo?

    var id: String {
        torrentInfo?.torrentURL
            ?? [torrentInfo?.siteName, torrentInfo?.title].compactMap { $0 }.joined(separator: "|")
    }

    var displayTitle: String {
        torrentInfo?.title?.nonEmpty
            ?? metaInfo?.name?.nonEmpty
            ?? mediaInfo?.title?.nonEmpty
            ?? "未命名资源"
    }

    func matchPriority(season: Int?, episode: Int?) -> Int {
        guard let season else { return 0 }
        let seasonCode = String(format: "S%02d", season)
        let episodeCode = episode.map { String(format: "E%02d", $0) }
        let haystack = [
            metaInfo?.seasonEpisode,
            torrentInfo?.title,
            metaInfo?.name
        ]
        .compactMap { $0 }
        .joined(separator: " ")
        .uppercased()

        if let episodeCode, haystack.contains(seasonCode + episodeCode) {
            return 0
        }
        if haystack.range(
            of: #"\#(seasonCode)(?!E\d+)"#,
            options: .regularExpression
        ) != nil {
            return 1
        }
        if haystack.contains(seasonCode) {
            return 2
        }
        if metaInfo?.seasonEpisode == nil {
            return 3
        }
        return 4
    }

    private enum CodingKeys: String, CodingKey {
        case torrentInfo = "torrent_info"
        case mediaInfo = "media_info"
        case metaInfo = "meta_info"
    }
}

struct MoviePilotTorrentInfo: Codable, Sendable {
    let title: String?
    let size: String?
    let seeders: Int?
    let peers: Int?
    let siteName: String?
    let torrentURL: String?
    let pageURL: String?
    let volumeFactor: String?
    let freeDateDifference: String?
    let publishedAt: String?

    private enum CodingKeys: String, CodingKey {
        case title, size, seeders, peers
        case siteName = "site_name"
        case torrentURL = "torrent_url"
        case pageURL = "page_url"
        case volumeFactor = "volume_factor"
        case freeDateDifference = "freedate_diff"
        case publishedAt = "pubdate"
    }
}

struct MoviePilotTorrentMediaInfo: Codable, Sendable {
    let title: String?
    let englishTitle: String?
    let year: String?
    let type: String?
    let season: Int?
    let tmdbId: Int?

    private enum CodingKeys: String, CodingKey {
        case title, year, type, season
        case englishTitle = "en_title"
        case tmdbId = "tmdb_id"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        title = try container.decodeIfPresent(String.self, forKey: .title)
        englishTitle = try container.decodeIfPresent(String.self, forKey: .englishTitle)
        year = try container.decodeFlexibleStringIfPresent(forKey: .year)
        type = try container.decodeIfPresent(String.self, forKey: .type)
        season = try container.decodeIfPresent(Int.self, forKey: .season)
        tmdbId = try container.decodeIfPresent(Int.self, forKey: .tmdbId)
    }
}

struct MoviePilotTorrentMetaInfo: Codable, Sendable {
    let name: String?
    let chineseName: String?
    let englishName: String?
    let year: String?
    let type: String?
    let beginSeason: Int?
    let seasonEpisode: String?
    let resourceTeam: String?
    let videoEncode: String?
    let edition: String?
    let resourceResolution: String?

    private enum CodingKeys: String, CodingKey {
        case name, year, type, edition
        case chineseName = "cn_name"
        case englishName = "en_name"
        case beginSeason = "begin_season"
        case seasonEpisode = "season_episode"
        case resourceTeam = "resource_team"
        case videoEncode = "video_encode"
        case resourceResolution = "resource_pix"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decodeIfPresent(String.self, forKey: .name)
        chineseName = try container.decodeIfPresent(String.self, forKey: .chineseName)
        englishName = try container.decodeIfPresent(String.self, forKey: .englishName)
        year = try container.decodeFlexibleStringIfPresent(forKey: .year)
        type = try container.decodeIfPresent(String.self, forKey: .type)
        beginSeason = try container.decodeIfPresent(Int.self, forKey: .beginSeason)
        seasonEpisode = try container.decodeIfPresent(String.self, forKey: .seasonEpisode)
        resourceTeam = try container.decodeIfPresent(String.self, forKey: .resourceTeam)
        videoEncode = try container.decodeIfPresent(String.self, forKey: .videoEncode)
        edition = try container.decodeIfPresent(String.self, forKey: .edition)
        resourceResolution = try container.decodeIfPresent(String.self, forKey: .resourceResolution)
    }
}

struct MoviePilotSearchFilters: Codable, Equatable, Sendable {
    var sites: Set<String> = []
    var seasons: Set<String> = []
    var freeStates: Set<String> = []
    var videoCodes: Set<String> = []
    var editions: Set<String> = []
    var resolutions: Set<String> = []
    var releaseGroups: Set<String> = []
    var titlePattern = ""

    var isEmpty: Bool {
        sites.isEmpty &&
        seasons.isEmpty &&
        freeStates.isEmpty &&
        videoCodes.isEmpty &&
        editions.isEmpty &&
        resolutions.isEmpty &&
        releaseGroups.isEmpty &&
        titlePattern.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

struct MoviePilotResourceSearchSnapshot: Codable, Sendable {
    let summary: MoviePilotTorrentSearchSummary
    let results: [MoviePilotTorrentSearchResult]
    let cachedAt: Date

    func page(
        filters: MoviePilotSearchFilters,
        requestedPage: Int,
        pageSize: Int = 50
    ) -> MoviePilotTorrentSearchPage {
        let filteredResults = results.filter { result in
            matches(filters.sites, value: result.torrentInfo?.siteName) &&
            matches(filters.seasons, value: result.metaInfo?.seasonEpisode) &&
            matches(filters.freeStates, value: result.torrentInfo?.volumeFactor) &&
            matches(filters.videoCodes, value: result.metaInfo?.videoEncode) &&
            matches(filters.editions, value: result.metaInfo?.edition) &&
            matches(filters.resolutions, value: result.metaInfo?.resourceResolution) &&
            matches(filters.releaseGroups, value: result.metaInfo?.resourceTeam) &&
            matchesTitle(filters.titlePattern, result: result)
        }

        let safePageSize = max(pageSize, 1)
        let totalPages = filteredResults.isEmpty
            ? 0
            : Int(ceil(Double(filteredResults.count) / Double(safePageSize)))
        let page = min(max(requestedPage, 1), max(totalPages, 1))
        let start = min((page - 1) * safePageSize, filteredResults.count)
        let end = min(start + safePageSize, filteredResults.count)

        return MoviePilotTorrentSearchPage(
            totalCount: filteredResults.count,
            page: page,
            totalPages: totalPages,
            results: Array(filteredResults[start..<end]),
            message: nil
        )
    }

    private func matches(_ selection: Set<String>, value: String?) -> Bool {
        selection.isEmpty || value.map(selection.contains) == true
    }

    private func matchesTitle(
        _ pattern: String,
        result: MoviePilotTorrentSearchResult
    ) -> Bool {
        let trimmed = pattern.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return true }
        return result.displayTitle.localizedCaseInsensitiveContains(trimmed)
    }
}

enum MoviePilotToolTextDecoder {
    static func decodeArray<T: Decodable>(_ type: T.Type, from text: String) throws -> [T] {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty ||
            trimmed.hasPrefix("未找到") ||
            trimmed.hasPrefix("暂无") ||
            trimmed == "媒体库中未找到相关媒体" {
            return []
        }
        return try decode([T].self, from: trimmed)
    }

    static func decode<T: Decodable>(_ type: T.Type, from text: String) throws -> T {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw MoviePilotError.decodingError("MoviePilot 返回了空结果")
        }

        let decoder = JSONDecoder()
        if let data = trimmed.data(using: .utf8),
           let decoded = try? decoder.decode(type, from: data) {
            return decoded
        }

        if let start = trimmed.firstIndex(of: "{"),
           let end = trimmed.lastIndex(of: "}"),
           start <= end {
            let candidate = String(trimmed[start...end])
            if let decoded = try? decoder.decode(type, from: Data(candidate.utf8)) {
                return decoded
            }
        }

        if let start = trimmed.firstIndex(of: "["),
           let end = trimmed.lastIndex(of: "]"),
           start <= end {
            let candidate = String(trimmed[start...end])
            if let decoded = try? decoder.decode(type, from: Data(candidate.utf8)) {
                return decoded
            }
        }

        throw MoviePilotError.decodingError(trimmed)
    }
}

private extension String {
    var nonEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

private extension KeyedDecodingContainer {
    func decodeFlexibleStringIfPresent(forKey key: Key) throws -> String? {
        if let value = try? decode(String.self, forKey: key) {
            return value
        }
        if let value = try? decode(Int.self, forKey: key) {
            return String(value)
        }
        if let value = try? decode(Double.self, forKey: key) {
            return String(value)
        }
        return nil
    }
}
