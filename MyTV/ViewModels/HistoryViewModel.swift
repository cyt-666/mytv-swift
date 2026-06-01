import Foundation

@Observable
@MainActor
final class HistoryViewModel {
    var items: [HistoryItem] = []
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

        do {
            let result = try await UserAPI.history(limit: 50)
            items = result.map { item in
                HistoryItem(
                    title: item.movie?.title ?? item.show?.title ?? item.episode?.title ?? "未知",
                    watchedAt: formatDate(item.watchedAt),
                    mediaType: item.type,
                    traktId: item.movie?.ids.trakt ?? item.show?.ids.trakt ?? 0,
                    posterURL: item.movie?.images?.poster?.first ?? item.show?.images?.poster?.first
                )
            }
        } catch {
            print("加载观看历史失败: \(error)")
            errorMessage = "加载失败: \(error.localizedDescription)"
        }
    }

    private func formatDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date = formatter.date(from: dateString) else { return dateString }
        let displayFormatter = DateFormatter()
        displayFormatter.dateFormat = "yyyy-MM-dd HH:mm"
        displayFormatter.locale = Locale(identifier: "zh_CN")
        return displayFormatter.string(from: date)
    }
}

struct HistoryItem: Identifiable {
    let id = UUID()
    let title: String
    let watchedAt: String
    let mediaType: String
    let traktId: Int
    let posterURL: String?
}
