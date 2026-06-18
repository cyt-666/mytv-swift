import SwiftUI

struct RecommendationsView: View {
    let type: String // "movies" or "shows"
    @State private var viewModel = RecommendationsViewModel()

    var title: String { type == "movies" ? "推荐电影" : "推荐剧集" }

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.items.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = viewModel.errorMessage, viewModel.items.isEmpty {
                ContentUnavailableView {
                    Text(error)
                } actions: {
                    Button("重试") { Task { await viewModel.load(type: type, reset: true) } }
                }
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text(title)
                            .font(.system(size: 24, weight: .bold))
                            .padding(.horizontal, 20)
                            .padding(.top, 60)

                        MediaGridView(
                            items: viewModel.items,
                            onItemAppear: { item in
                                Task { await viewModel.loadMoreIfNeeded(currentItem: item) }
                            }
                        )
                        .padding(.horizontal, 20)

                        PaginationFooterView(
                            isLoadingMore: viewModel.isLoadingMore,
                            canLoadMore: viewModel.canLoadMore,
                            errorMessage: viewModel.errorMessage,
                            onRetry: {
                                Task { await viewModel.loadMoreIfNeeded() }
                            }
                        )
                        .padding(.bottom, 24)
                    }
                }
            }
        }
        .task(id: type) { await viewModel.load(type: type, reset: true) }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    Task { await viewModel.load(type: type, reset: true) }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .symbolEffect(.rotate, isActive: viewModel.isLoading)
                }
                .disabled(viewModel.isLoading || viewModel.isLoadingMore)
                .help("刷新")
            }
        }
    }
}

@Observable
@MainActor
private final class RecommendationsViewModel {
    var items: [MediaItem] = []
    var isLoading = false
    var isLoadingMore = false
    var canLoadMore = true
    var errorMessage: String?

    private var type = ""
    private var page = 1
    private let pageSize = 30
    private let loadMoreThreshold = 6

    func load(type: String, reset: Bool = true) async {
        guard !isLoading else { return }

        if reset || type != self.type {
            self.type = type
            page = 1
            canLoadMore = true
            items = []
        }

        errorMessage = nil
        isLoading = true
        defer { isLoading = false }

        do {
            let newItems = try await fetchPage(page)
            items = uniqueItems(from: newItems)
            canLoadMore = newItems.count == pageSize && !items.isEmpty
        } catch {
            errorMessage = "加载失败: \(error.localizedDescription)"
            canLoadMore = false
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
            errorMessage = "加载更多失败: \(error.localizedDescription)"
        }
    }

    private func fetchPage(_ page: Int) async throws -> [MediaItem] {
        if type == "movies" {
            let movies = try await RecommendationAPI.movies(page: page, limit: pageSize)
            return movies.map { .movie($0) }
        } else {
            let shows = try await RecommendationAPI.shows(page: page, limit: pageSize)
            return shows.map { .show($0) }
        }
    }

    private func shouldLoadMore(for currentItem: MediaItem?) -> Bool {
        guard canLoadMore, !type.isEmpty, !isLoading, !isLoadingMore else { return false }
        guard let currentItem else { return true }
        guard let index = items.firstIndex(where: { $0.id == currentItem.id }) else {
            return false
        }
        let thresholdIndex = max(items.count - loadMoreThreshold, 0)
        return index >= thresholdIndex
    }

    private func appendUnique(_ newItems: [MediaItem]) -> Int {
        let uniqueItems = uniqueItems(from: newItems, excluding: Set(items.map(\.id)))
        items.append(contentsOf: uniqueItems)
        return uniqueItems.count
    }

    private func uniqueItems(from newItems: [MediaItem], excluding existingIds: Set<String> = []) -> [MediaItem] {
        var seenIds = existingIds
        return newItems.filter { item in
            guard !seenIds.contains(item.id) else { return false }
            seenIds.insert(item.id)
            return true
        }
    }
}
