import Foundation

@Observable
@MainActor
final class MoviesViewModel {
    enum Tab: String, CaseIterable {
        case trending, popular, anticipated
    }

    var selectedTab: Tab = .trending
    var items: [MovieDTO] = []
    var isLoading = false
    var isLoadingMore = false
    var canLoadMore = true
    var errorMessage: String?

    private var page = 1
    private let pageSize = 20
    private let loadMoreThreshold = 6

    func load(reset: Bool = true) async {
        guard !isLoading else { return }

        if reset {
            page = 1
            canLoadMore = true
            items = []
        }

        errorMessage = nil
        isLoading = true
        defer { isLoading = false }

        do {
            let newItems = try await fetchPage(page)
            items = newItems
            canLoadMore = newItems.count == pageSize
        } catch {
            errorMessage = L10n.string("加载电影列表失败: %@", error.localizedDescription)
            canLoadMore = false
            print(errorMessage ?? L10n.string("加载电影列表失败"))
        }
    }

    func loadMoreIfNeeded(currentItem: MovieDTO? = nil) async {
        guard shouldLoadMore(for: currentItem) else { return }

        errorMessage = nil
        isLoadingMore = true
        defer { isLoadingMore = false }

        do {
            let nextPage = page + 1
            let newItems = try await fetchPage(nextPage)
            page = nextPage
            let appendedCount = appendUnique(newItems)
            canLoadMore = newItems.count == pageSize && appendedCount > 0
        } catch {
            errorMessage = L10n.string("加载更多电影失败: %@", error.localizedDescription)
            print(errorMessage ?? L10n.string("加载更多电影失败"))
        }
    }

    private func shouldLoadMore(for currentItem: MovieDTO?) -> Bool {
        guard canLoadMore, !isLoading, !isLoadingMore else { return false }
        guard let currentItem else { return true }
        guard let index = items.firstIndex(where: { $0.ids.trakt == currentItem.ids.trakt }) else {
            return false
        }
        let thresholdIndex = max(items.count - loadMoreThreshold, 0)
        return index >= thresholdIndex
    }

    private func appendUnique(_ newItems: [MovieDTO]) -> Int {
        let existingIds = Set(items.map(\.ids.trakt))
        let uniqueItems = newItems.filter { !existingIds.contains($0.ids.trakt) }
        items.append(contentsOf: uniqueItems)
        return uniqueItems.count
    }

    private func fetchPage(_ page: Int) async throws -> [MovieDTO] {
        switch selectedTab {
        case .trending:
            let result = try await MovieAPI.trending(page: page, limit: pageSize)
            return result.map(\.movie)
        case .popular:
            return try await MovieAPI.popular(page: page, limit: pageSize)
        case .anticipated:
            let result = try await MovieAPI.anticipated(page: page, limit: pageSize)
            return result.map(\.movie)
        }
    }
}
