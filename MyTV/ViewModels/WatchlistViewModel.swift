import Foundation

@Observable
@MainActor
final class WatchlistViewModel {
    enum Source: String, CaseIterable {
        case watchlist
        case customList

        var title: String {
            switch self {
            case .watchlist: return L10n.string("观看清单")
            case .customList: return L10n.string("自定义列表")
            }
        }
    }

    var source: Source = .watchlist
    var mediaType = "movies"
    var items: [MediaItem] = []
    var customLists: [TraktListDTO] = []
    var selectedListId: Int?
    var isLoading = false
    var errorMessage: String?

    var selectedList: TraktListDTO? {
        customLists.first { $0.ids.trakt == selectedListId }
    }

    var emptyTitle: String {
        if source == .customList {
            return customLists.isEmpty ? L10n.string("暂无自定义列表") : L10n.string("这个列表暂无内容")
        }
        return L10n.string("暂无观看清单")
    }

    var emptyDescription: String {
        if source == .customList {
            return customLists.isEmpty ? L10n.string("创建的 Trakt 自定义列表会显示在这里") : L10n.string("这个自定义列表中的电影和剧集会显示在这里")
        }
        return L10n.string("收藏的电影和剧集会显示在这里")
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            switch source {
            case .watchlist:
                try await loadWatchlist()
            case .customList:
                try await loadCustomList()
            }
        } catch {
            errorMessage = L10n.string("加载列表失败")
            print("加载列表失败: \(error)")
        }
    }

    func refresh() async {
        CacheService.clearAllAPIResponses()
        await load()
    }

    private func loadWatchlist() async throws {
        if mediaType == "movies" {
            let result: [WatchlistMovieDTO] = try await TraktAPIClient.shared.request(
                uri: "/users/me/watchlist/movies",
                params: ["extended": "full,images"],
                requiresAuth: true
            )
            items = result.map { .movie($0.movie) }
        } else {
            let result: [WatchlistShowDTO] = try await TraktAPIClient.shared.request(
                uri: "/users/me/watchlist/shows",
                params: ["extended": "full,images"],
                requiresAuth: true
            )
            items = result.map { .show($0.show) }
        }
    }

    private func loadCustomList() async throws {
        let profile = try await UserAPI.profile()
        let username = profile.user.ids.slug
        customLists = try await UserAPI.customLists(username: username)

        if selectedListId == nil || selectedList == nil {
            selectedListId = customLists.first?.ids.trakt
        }

        guard let listId = selectedListId else {
            items = []
            return
        }

        let result = try await ListAPI.items(username: username, listId: listId, type: mediaType)
        if mediaType == "movies" {
            items = result.compactMap { item in
                item.movie.map { .movie($0) }
            }
        } else {
            items = result.compactMap { item in
                item.show.map { .show($0) }
            }
        }
    }

    func selectValidCustomListIfNeeded() {
        guard source == .customList else { return }
        if selectedListId == nil || selectedList == nil {
            selectedListId = customLists.first?.ids.trakt
        }
    }

    func customListTitle(for listId: Int?) -> String {
        guard let listId else { return L10n.string("选择列表") }
        return customLists.first { $0.ids.trakt == listId }?.name ?? L10n.string("选择列表")
    }
}

struct WatchlistMovieDTO: Codable, Identifiable {
    let listedAt: String
    let movie: MovieDTO
    var id: Int { movie.ids.trakt }
    enum CodingKeys: String, CodingKey { case listedAt = "listed_at"; case movie }
}
