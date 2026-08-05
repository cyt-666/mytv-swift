import Foundation

enum MoviePilotEpisodeState: String, CaseIterable, Sendable {
    case inLibrary
    case downloading
    case pendingLibrary
    case unaired
    case subscribed
    case missing

    var displayName: String {
        switch self {
        case .inLibrary: return "已入库"
        case .downloading: return "下载中"
        case .pendingLibrary: return "待入库"
        case .unaired: return "未播出"
        case .subscribed: return "已订阅"
        case .missing: return "缺失"
        }
    }

    var systemImage: String {
        switch self {
        case .inLibrary: return "checkmark.circle.fill"
        case .downloading: return "arrow.down.circle.fill"
        case .pendingLibrary: return "shippingbox.circle.fill"
        case .unaired: return "calendar.badge.clock"
        case .subscribed: return "checkmark.seal.fill"
        case .missing: return "exclamationmark.circle.fill"
        }
    }
}

struct MoviePilotEpisodeStateSummary: Equatable, Sendable {
    let inLibrary: Int
    let downloading: Int
    let pendingLibrary: Int
    let missing: Int

    init(states: some Sequence<MoviePilotEpisodeState>) {
        var counts: [MoviePilotEpisodeState: Int] = [:]
        for state in states {
            counts[state, default: 0] += 1
        }
        inLibrary = counts[.inLibrary, default: 0]
        downloading = counts[.downloading, default: 0]
        pendingLibrary = counts[.pendingLibrary, default: 0]
        missing = counts[.missing, default: 0]
    }
}

enum MoviePilotEpisodeStateResolver {
    static func states(
        for episodes: [EpisodeDTO],
        status: MoviePilotMediaStatus,
        now: Date = Date()
    ) -> [Int: MoviePilotEpisodeState] {
        Dictionary(uniqueKeysWithValues: episodes.compactMap { episode in
            guard let state = state(
                season: episode.season,
                episode: episode.number,
                firstAired: episode.firstAired,
                status: status,
                now: now
            ) else {
                return nil
            }
            return (episode.number, state)
        })
    }

    static func state(
        season: Int,
        episode: Int,
        firstAired: String?,
        status: MoviePilotMediaStatus,
        now: Date = Date()
    ) -> MoviePilotEpisodeState? {
        guard season > 0 else { return nil }

        if isInLibrary(season: season, episode: episode, status: status) {
            return .inLibrary
        }

        let matchingDownloads = status.downloads.filter {
            download($0, matchesSeason: season, episode: episode)
        }
        if matchingDownloads.contains(where: { !$0.isCompleted }) {
            return .downloading
        }
        if matchingDownloads.contains(where: \.isCompleted) {
            return .pendingLibrary
        }

        guard let firstAired,
              let airDate = parseTraktDate(firstAired),
              airDate <= now else {
            return .unaired
        }

        if status.subscriptions.contains(where: { $0.season == nil || $0.season == season }) {
            return .subscribed
        }

        return .missing
    }

    private static func isInLibrary(
        season: Int,
        episode: Int,
        status: MoviePilotMediaStatus
    ) -> Bool {
        status.libraryItems.contains { item in
            item.servers.values.contains { server in
                guard let seasons = server.seasons else { return false }
                return seasons.contains { key, value in
                    parsedNumber(from: key, marker: "S") == season &&
                    value.existingEpisodes.contains(episode)
                }
            }
        }
    }

    private static func download(
        _ task: MoviePilotDownloadTask,
        matchesSeason season: Int,
        episode: Int
    ) -> Bool {
        let mediaSeason = parsedNumber(from: task.media?.season, marker: "S")
        let mediaEpisode = parsedNumber(from: task.media?.episode, marker: "E")

        if let mediaSeason {
            guard mediaSeason == season else { return false }
            return mediaEpisode == nil || mediaEpisode == episode
        }

        let values = [task.seasonEpisode, task.title, task.name]
            .compactMap { $0 }
            .joined(separator: " ")
        guard containsMarker("S", number: season, in: values) else {
            return false
        }

        let hasAnyEpisode = values.range(
            of: #"(?i)E\d{1,4}(?!\d)"#,
            options: .regularExpression
        ) != nil
        return !hasAnyEpisode || containsMarker("E", number: episode, in: values)
    }

    private static func parsedNumber(from value: String?, marker: Character) -> Int? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if let number = Int(trimmed) {
            return number
        }

        let pattern = #"(?i)\#(marker)\s*0*(\d+)"#
        guard let range = trimmed.range(of: pattern, options: .regularExpression) else {
            return nil
        }
        let matched = String(trimmed[range])
        let digits = matched.filter(\.isNumber)
        return Int(digits)
    }

    private static func containsMarker(_ marker: Character, number: Int, in value: String) -> Bool {
        value.range(
            of: #"(?i)\#(marker)0*\#(number)(?!\d)"#,
            options: .regularExpression
        ) != nil
    }

    private static func parseTraktDate(_ value: String) -> Date? {
        let fractionalStyle = Date.ISO8601FormatStyle(includingFractionalSeconds: true)
        if let date = try? fractionalStyle.parse(value) {
            return date
        }
        return try? Date.ISO8601FormatStyle().parse(value)
    }
}

actor MoviePilotMediaStatusProvider {
    static let shared = MoviePilotMediaStatusProvider()

    private var cache: [MoviePilotMediaTarget: MoviePilotMediaStatus] = [:]
    private var inFlight: [MoviePilotMediaTarget: Task<MoviePilotMediaStatus, Error>] = [:]

    func status(
        for target: MoviePilotMediaTarget,
        forceRefresh: Bool = false
    ) async throws -> MoviePilotMediaStatus {
        if !forceRefresh, let cached = cache[target] {
            return cached
        }
        if !forceRefresh, let task = inFlight[target] {
            return try await task.value
        }

        let task = Task {
            try await MoviePilotAPIClient.shared.fetchStatus(for: target)
        }
        inFlight[target] = task

        do {
            let status = try await task.value
            cache[target] = status
            inFlight[target] = nil
            return status
        } catch {
            inFlight[target] = nil
            throw error
        }
    }

    func invalidate(_ target: MoviePilotMediaTarget? = nil) {
        if let target {
            cache[target] = nil
            inFlight[target]?.cancel()
            inFlight[target] = nil
        } else {
            cache.removeAll()
            inFlight.values.forEach { $0.cancel() }
            inFlight.removeAll()
        }
    }
}
