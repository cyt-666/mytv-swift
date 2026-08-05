import Foundation

@Observable
@MainActor
final class CalendarViewModel {
    var groupedShows: [CalendarGroup] = []
    var moviePilotStates: [String: MoviePilotEpisodeState] = [:]
    var isLoading = false
    var isLoadingMoviePilotStates = false
    var errorMessage: String?

    let daysToLoad = 14
    private var moviePilotStateTask: Task<Void, Never>?

    var totalEpisodeCount: Int {
        groupedShows.reduce(0) { $0 + $1.shows.count }
    }

    var todayEpisodeCount: Int {
        groupedShows.first(where: \.isToday)?.shows.count ?? 0
    }

    var rangeTitle: String {
        guard let firstDate = groupedShows.first?.date,
              let lastDate = groupedShows.last?.date else {
            return L10n.string("未来 %d 天", daysToLoad)
        }
        return "\(Self.monthDayFormatter().string(from: firstDate)) - \(Self.monthDayFormatter().string(from: lastDate))"
    }

    func load() async {
        guard AuthService.shared.isLoggedIn else {
            errorMessage = L10n.string("请先登录")
            return
        }
        moviePilotStateTask?.cancel()
        isLoading = true
        errorMessage = nil
        moviePilotStates = [:]

        let startDate = Self.apiDateFormatter.string(from: Date())

        do {
            let shows = try await CalendarAPI.myShows(startDate: startDate, days: daysToLoad)
            groupedShows = makeGroups(from: shows)
            isLoading = false
            moviePilotStateTask = Task { [weak self] in
                await self?.loadMoviePilotStates(for: shows)
            }
        } catch {
            print("加载日历失败: \(error)")
            errorMessage = L10n.string("加载失败: %@", error.localizedDescription)
            isLoading = false
        }
    }

    func refresh() async {
        moviePilotStateTask?.cancel()
        await MoviePilotMediaStatusProvider.shared.invalidate()
        CacheService.clearAllAPIResponses()
        await load()
    }

    private func loadMoviePilotStates(for shows: [CalendarShowDTO]) async {
        guard (try? MoviePilotSettingsStore.currentConfiguration()) != nil else {
            isLoadingMoviePilotStates = false
            return
        }

        let targetsByTMDB = Dictionary(
            shows.compactMap { item -> (Int, MoviePilotMediaTarget)? in
                guard let tmdbId = item.show.ids.tmdb,
                      item.episode?.season ?? 0 > 0 else {
                    return nil
                }
                return (tmdbId, .show(item.show))
            },
            uniquingKeysWith: { first, _ in first }
        )
        guard !targetsByTMDB.isEmpty else {
            isLoadingMoviePilotStates = false
            return
        }

        isLoadingMoviePilotStates = true
        defer { isLoadingMoviePilotStates = false }

        let targets = targetsByTMDB.map { (tmdbId: $0.key, target: $0.value) }
        var statusesByTMDB: [Int: MoviePilotMediaStatus] = [:]
        let concurrencyLimit = 4

        for startIndex in stride(from: 0, to: targets.count, by: concurrencyLimit) {
            guard !Task.isCancelled else { return }
            let endIndex = min(startIndex + concurrencyLimit, targets.count)
            let batch = Array(targets[startIndex..<endIndex])

            await withTaskGroup(of: (Int, MoviePilotMediaStatus?).self) { group in
                for entry in batch {
                    group.addTask {
                        do {
                            let status = try await MoviePilotMediaStatusProvider.shared.status(
                                for: entry.target
                            )
                            return (entry.tmdbId, status)
                        } catch {
                            return (entry.tmdbId, nil)
                        }
                    }
                }

                for await (tmdbId, status) in group {
                    if let status {
                        statusesByTMDB[tmdbId] = status
                    }
                }
            }
        }

        guard !Task.isCancelled else { return }
        moviePilotStates = Dictionary(
            shows.compactMap { item -> (String, MoviePilotEpisodeState)? in
                guard let episode = item.episode,
                      let tmdbId = item.show.ids.tmdb,
                      let status = statusesByTMDB[tmdbId],
                      let state = MoviePilotEpisodeStateResolver.state(
                          season: episode.season,
                          episode: episode.number,
                          firstAired: episode.firstAired ?? item.firstAired,
                          status: status
                      ) else {
                    return nil
                }
                return (item.id, state)
            },
            uniquingKeysWith: { first, _ in first }
        )
    }

    private func makeGroups(from shows: [CalendarShowDTO]) -> [CalendarGroup] {
        let grouped = Dictionary(grouping: shows) { show in
            dateKey(for: show) ?? "unknown"
        }

        return grouped.map { key, shows in
            let date = Self.apiDateFormatter.date(from: key)
            let sortedShows = shows.sorted { lhs, rhs in
                (Self.parseTraktDate(lhs.firstAired ?? "") ?? .distantPast)
                    < (Self.parseTraktDate(rhs.firstAired ?? "") ?? .distantPast)
            }

            return CalendarGroup(
                id: key,
                date: date,
                monthDay: date.map { Self.monthDayFormatter().string(from: $0) } ?? L10n.string("未知日期"),
                weekday: date.map { Self.weekdayFormatter().string(from: $0) } ?? "",
                relativeTitle: relativeTitle(for: date),
                shows: sortedShows
            )
        }
        .sorted { lhs, rhs in
            switch (lhs.date, rhs.date) {
            case let (lhsDate?, rhsDate?):
                return lhsDate < rhsDate
            case (.some, .none):
                return true
            case (.none, .some):
                return false
            case (.none, .none):
                return lhs.id < rhs.id
            }
        }
    }

    private func dateKey(for show: CalendarShowDTO) -> String? {
        guard let firstAired = show.firstAired,
              let date = Self.parseTraktDate(firstAired) else {
            return nil
        }
        return Self.apiDateFormatter.string(from: date)
    }

    private func relativeTitle(for date: Date?) -> String {
        guard let date else { return L10n.string("待定") }
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return L10n.string("今天") }
        if calendar.isDateInTomorrow(date) { return L10n.string("明天") }
        return Self.weekdayFormatter().string(from: date)
    }

    static func parseTraktDate(_ value: String) -> Date? {
        traktDateParserWithFractionalSeconds.date(from: value) ?? traktDateParser.date(from: value)
    }

    private static let apiDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private static func monthDayFormatter() -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = L10n.locale
        formatter.setLocalizedDateFormatFromTemplate("MMMd")
        return formatter
    }

    private static func weekdayFormatter() -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = L10n.locale
        formatter.setLocalizedDateFormatFromTemplate("EEEE")
        return formatter
    }

    private static let traktDateParserWithFractionalSeconds: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let traktDateParser: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()
}

struct CalendarGroup: Identifiable {
    let id: String
    let date: Date?
    let monthDay: String
    let weekday: String
    let relativeTitle: String
    let shows: [CalendarShowDTO]

    var isToday: Bool {
        date.map(Calendar.current.isDateInToday) ?? false
    }
}
