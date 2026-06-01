import Foundation

@Observable
@MainActor
final class CalendarViewModel {
    var groupedShows: [CalendarGroup] = []
    var isLoading = false
    var errorMessage: String?

    func load() async {
        guard AuthService.shared.isLoggedIn else {
            errorMessage = "请先登录"
            return
        }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let startDate = formatter.string(from: Date())

        do {
            let shows = try await CalendarAPI.myShows(startDate: startDate, days: 7)
            let grouped = Dictionary(grouping: shows) { show in
                show.firstAired.map { String($0.prefix(10)) } ?? "未知日期"
            }
            groupedShows = grouped.map { CalendarGroup(date: formatDisplayDate($0.key), shows: $0.value) }
                .sorted { $0.date < $1.date }
        } catch {
            print("加载日历失败: \(error)")
            errorMessage = "加载失败: \(error.localizedDescription)"
        }
    }

    private func formatDisplayDate(_ dateString: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        guard let date = formatter.date(from: dateString) else { return dateString }
        let displayFormatter = DateFormatter()
        displayFormatter.dateFormat = "MM月dd日 EEEE"
        displayFormatter.locale = Locale(identifier: "zh_CN")
        return displayFormatter.string(from: date)
    }
}

struct CalendarGroup: Identifiable {
    let id = UUID()
    let date: String
    let shows: [CalendarShowDTO]
}
