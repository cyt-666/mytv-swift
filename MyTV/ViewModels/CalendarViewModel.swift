import Foundation

@Observable
@MainActor
final class CalendarViewModel {
    var groupedShows: [CalendarGroup] = []
    var isLoading = false
    var errorMessage: String?

    let daysToLoad = 14

    var totalEpisodeCount: Int {
        groupedShows.reduce(0) { $0 + $1.shows.count }
    }

    var todayEpisodeCount: Int {
        groupedShows.first(where: \.isToday)?.shows.count ?? 0
    }

    var rangeTitle: String {
        guard let firstDate = groupedShows.first?.date,
              let lastDate = groupedShows.last?.date else {
            return "未来 \(daysToLoad) 天"
        }
        return "\(Self.monthDayFormatter.string(from: firstDate)) - \(Self.monthDayFormatter.string(from: lastDate))"
    }

    func load() async {
        guard AuthService.shared.isLoggedIn else {
            errorMessage = "请先登录"
            return
        }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        let startDate = Self.apiDateFormatter.string(from: Date())

        do {
            let shows = try await CalendarAPI.myShows(startDate: startDate, days: daysToLoad)
            groupedShows = makeGroups(from: shows)
        } catch {
            print("加载日历失败: \(error)")
            errorMessage = "加载失败: \(error.localizedDescription)"
        }
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
                monthDay: date.map { Self.monthDayFormatter.string(from: $0) } ?? "未知日期",
                weekday: date.map { Self.weekdayFormatter.string(from: $0) } ?? "",
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
        guard let date else { return "待定" }
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "今天" }
        if calendar.isDateInTomorrow(date) { return "明天" }
        return Self.weekdayFormatter.string(from: date)
    }

    static func parseTraktDate(_ value: String) -> Date? {
        traktDateParserWithFractionalSeconds.date(from: value) ?? traktDateParser.date(from: value)
    }

    private static let apiDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private static let monthDayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M月d日"
        return formatter
    }()

    private static let weekdayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "EEEE"
        return formatter
    }()

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
