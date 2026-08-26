import Foundation

@Observable
@MainActor
final class HistoryViewModel {
    enum Filter: String, CaseIterable, Hashable {
        case all
        case movies
        case shows

        var title: String {
            switch self {
            case .all:
                return L10n.string("全部")
            case .movies:
                return L10n.string("电影")
            case .shows:
                return L10n.string("剧集")
            }
        }

        var apiType: String? {
            switch self {
            case .all:
                return nil
            case .movies:
                return "movies"
            case .shows:
                return "shows"
            }
        }
    }

    var items: [HistoryItem] = []
    var selectedFilter: Filter = .all
    var isLoading = false
    var errorMessage: String?
    private var loadRequestID = 0

    func load() async {
        guard AuthService.shared.isLoggedIn else {
            items = []
            errorMessage = "请先登录"
            return
        }

        loadRequestID += 1
        let requestID = loadRequestID
        let targetFilter = selectedFilter

        isLoading = true
        errorMessage = nil
        items = []
        defer {
            if requestID == loadRequestID {
                isLoading = false
            }
        }

        do {
            let result = try await UserAPI.history(type: targetFilter.apiType, limit: 50)
            guard requestID == loadRequestID else { return }

            items = result.map { item in
                HistoryItem(
                    title: item.movie?.title ?? item.show?.title ?? item.episode?.title ?? "未知",
                    watchedAt: formatDate(item.watchedAt),
                    mediaType: item.type,
                    traktId: item.movie?.ids.trakt ?? item.show?.ids.trakt ?? 0,
                    seasonNumber: item.episode?.season,
                    episodeNumber: item.episode?.number,
                    episodeTitle: item.episode?.title,
                    posterURL: item.movie?.images?.poster?.first ?? item.show?.images?.poster?.first
                )
            }
        } catch {
            guard requestID == loadRequestID else { return }

            print("加载观看历史失败: \(error)")
            errorMessage = "加载失败: \(error.localizedDescription)"
        }
    }

    private func formatDate(_ dateString: String) -> String {
        let fractionalFormatter = ISO8601DateFormatter()
        fractionalFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]

        guard let date = fractionalFormatter.date(from: dateString) ?? formatter.date(from: dateString) else {
            return dateString
        }

        let displayFormatter = DateFormatter()
        displayFormatter.locale = L10n.locale
        displayFormatter.dateStyle = .medium
        displayFormatter.timeStyle = .short
        return displayFormatter.string(from: date)
    }
}

struct HistoryItem: Identifiable {
    let id = UUID()
    let title: String
    let watchedAt: String
    let mediaType: String
    let traktId: Int
    let seasonNumber: Int?
    let episodeNumber: Int?
    let episodeTitle: String?
    let posterURL: String?

    var episodeCode: String? {
        guard let seasonNumber, let episodeNumber else { return nil }
        return "S\(seasonNumber)E\(episodeNumber)"
    }

    func episodeLine(translatedTitle: String?) -> String? {
        guard let episodeCode else { return nil }
        let title = translatedTitle ?? episodeTitle
        guard let title, !title.isEmpty else { return episodeCode }
        return "\(episodeCode) · \(title)"
    }
}
