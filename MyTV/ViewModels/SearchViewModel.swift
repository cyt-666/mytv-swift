import Foundation

@Observable
@MainActor
final class SearchViewModel {
    var results: [MediaItem] = []
    var isLoading = false
    var isLoadingMore = false
    var canLoadMore = false
    var errorMessage: String?

    private var query = ""
    private var page = 1
    private let pageSize = 30
    private let loadMoreThreshold = 6

    func search(query: String) async {
        await load(query: query, reset: true)
    }

    func load(query: String, reset: Bool = true) async {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedQuery.isEmpty else {
            self.query = ""
            page = 1
            results = []
            canLoadMore = false
            errorMessage = nil
            return
        }

        guard !isLoading else { return }

        if reset || trimmedQuery != self.query {
            self.query = trimmedQuery
            page = 1
            canLoadMore = true
            results = []
        }

        errorMessage = nil
        isLoading = true
        defer { isLoading = false }

        do {
            let newItems = try await fetchPage(page)
            results = newItems
            canLoadMore = newItems.count == pageSize
        } catch {
            errorMessage = "搜索失败: \(error.localizedDescription)"
            canLoadMore = false
            print(errorMessage ?? "搜索失败")
        }
    }

    func loadMoreIfNeeded(currentItem: MediaItem? = nil) async {
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
            errorMessage = "加载更多搜索结果失败: \(error.localizedDescription)"
            print(errorMessage ?? "加载更多搜索结果失败")
        }
    }

    private func fetchPage(_ page: Int) async throws -> [MediaItem] {
        let searchResults = try await SearchAPI.search(query: query, page: page, limit: pageSize)
        return searchResults.compactMap { result in
            if let movie = result.movie {
                return MediaItem.movie(movie)
            } else if let show = result.show {
                return MediaItem.show(show)
            }
            return nil
        }
    }

    private func shouldLoadMore(for currentItem: MediaItem?) -> Bool {
        guard canLoadMore, !query.isEmpty, !isLoading, !isLoadingMore else { return false }
        guard let currentItem else { return true }
        guard let index = results.firstIndex(where: { $0.id == currentItem.id }) else {
            return false
        }
        let thresholdIndex = max(results.count - loadMoreThreshold, 0)
        return index >= thresholdIndex
    }

    private func appendUnique(_ newItems: [MediaItem]) -> Int {
        let existingIds = Set(results.map(\.id))
        let uniqueItems = newItems.filter { !existingIds.contains($0.id) }
        results.append(contentsOf: uniqueItems)
        return uniqueItems.count
    }
}
