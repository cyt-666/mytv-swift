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
                            items: viewModel.items
                        )
                        .padding(.horizontal, 20)
                    }
                }
            }
        }
        .task(id: type) { await viewModel.load(type: type, reset: true) }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    Task {
                        CacheService.clearAllAPIResponses()
                        await viewModel.load(type: type, reset: true)
                    }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .symbolEffect(.rotate, isActive: viewModel.isLoading)
                }
                .disabled(viewModel.isLoading)
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
    var errorMessage: String?

    private var type = ""
    private let recommendationLimit = 100

    func load(type: String, reset: Bool = true) async {
        guard !isLoading else { return }

        if reset || type != self.type {
            self.type = type
            items = []
        }

        errorMessage = nil
        isLoading = true
        defer { isLoading = false }

        do {
            let newItems = try await fetchRecommendations()
            items = uniqueItems(from: newItems)
        } catch {
            errorMessage = "加载失败: \(error.localizedDescription)"
        }
    }

    private func fetchRecommendations() async throws -> [MediaItem] {
        if type == "movies" {
            let movies = try await RecommendationAPI.movies(limit: recommendationLimit)
            return movies.map { .movie($0) }
        } else {
            let shows = try await RecommendationAPI.shows(limit: recommendationLimit)
            return shows.map { .show($0) }
        }
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
