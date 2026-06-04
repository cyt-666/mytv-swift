import Foundation

@Observable
@MainActor
final class ShowsViewModel {
    enum Tab: String, CaseIterable {
        case trending, popular, anticipated
    }

    var selectedTab: Tab = .trending
    var items: [ShowDTO] = []
    var isLoading = false
    var isLoadingMore = false
    var canLoadMore = true

    private var page = 1
    private let pageSize = 20

    func load() async {
        page = 1
        canLoadMore = true
        isLoading = true
        defer { isLoading = false }

        do {
            items = try await fetchPage(page)
            canLoadMore = items.count == pageSize
        } catch {
            print("加载剧集列表失败: \(error)")
        }
    }

    func loadMoreIfNeeded() async {
        guard canLoadMore, !isLoading, !isLoadingMore else { return }

        isLoadingMore = true
        defer { isLoadingMore = false }

        do {
            let nextPage = page + 1
            let newItems = try await fetchPage(nextPage)
            page = nextPage
            items.append(contentsOf: newItems)
            canLoadMore = newItems.count == pageSize
        } catch {
            print("加载更多剧集失败: \(error)")
        }
    }

    private func fetchPage(_ page: Int) async throws -> [ShowDTO] {
        switch selectedTab {
        case .trending:
            let result = try await ShowAPI.trending(page: page, limit: pageSize)
            return result.map(\.show)
        case .popular:
            return try await ShowAPI.popular(page: page, limit: pageSize)
        case .anticipated:
            let result = try await ShowAPI.anticipated(page: page, limit: pageSize)
            return result.map(\.show)
        }
    }
}
