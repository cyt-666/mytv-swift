import Foundation

struct BrowseFilterOption: Hashable, Identifiable {
    let title: String
    let value: String

    var id: String { value }

    var localizedTitle: String { L10n.string(title) }
}

@Observable
@MainActor
final class BrowseViewModel {
    var selectedGenre = ""
    var selectedCountry = ""
    var items: [MovieDTO] = []
    var isLoading = false
    var isLoadingMore = false
    var canLoadMore = true
    var errorMessage: String?

    private var page = 1
    private let pageSize = 30
    private let loadMoreThreshold = 6

    let genres = [
        BrowseFilterOption(title: "动作", value: "action"),
        BrowseFilterOption(title: "冒险", value: "adventure"),
        BrowseFilterOption(title: "动画", value: "animation"),
        BrowseFilterOption(title: "喜剧", value: "comedy"),
        BrowseFilterOption(title: "犯罪", value: "crime"),
        BrowseFilterOption(title: "纪录片", value: "documentary"),
        BrowseFilterOption(title: "剧情", value: "drama"),
        BrowseFilterOption(title: "家庭", value: "family"),
        BrowseFilterOption(title: "奇幻", value: "fantasy"),
        BrowseFilterOption(title: "历史", value: "history"),
        BrowseFilterOption(title: "恐怖", value: "horror"),
        BrowseFilterOption(title: "音乐", value: "music"),
        BrowseFilterOption(title: "悬疑", value: "mystery"),
        BrowseFilterOption(title: "浪漫", value: "romance"),
        BrowseFilterOption(title: "科幻", value: "science-fiction"),
        BrowseFilterOption(title: "电视电影", value: "tv-movie"),
        BrowseFilterOption(title: "惊悚", value: "thriller"),
        BrowseFilterOption(title: "战争", value: "war"),
        BrowseFilterOption(title: "西部", value: "western")
    ]

    let countries = [
        BrowseFilterOption(title: "美国", value: "us"),
        BrowseFilterOption(title: "英国", value: "gb"),
        BrowseFilterOption(title: "中国", value: "cn"),
        BrowseFilterOption(title: "日本", value: "jp"),
        BrowseFilterOption(title: "韩国", value: "kr"),
        BrowseFilterOption(title: "法国", value: "fr"),
        BrowseFilterOption(title: "德国", value: "de"),
        BrowseFilterOption(title: "加拿大", value: "ca"),
        BrowseFilterOption(title: "澳大利亚", value: "au"),
        BrowseFilterOption(title: "印度", value: "in"),
        BrowseFilterOption(title: "意大利", value: "it"),
        BrowseFilterOption(title: "西班牙", value: "es")
    ]

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
            errorMessage = L10n.string("加载分类数据失败: %@", error.localizedDescription)
            canLoadMore = false
            print(errorMessage ?? L10n.string("加载分类数据失败"))
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
            errorMessage = L10n.string("加载更多分类数据失败: %@", error.localizedDescription)
            print(errorMessage ?? L10n.string("加载更多分类数据失败"))
        }
    }

    private func fetchPage(_ page: Int) async throws -> [MovieDTO] {
        let genre = selectedGenre.isEmpty ? nil : selectedGenre
        let country = selectedCountry.isEmpty ? nil : selectedCountry
        return try await MovieAPI.popular(page: page, limit: pageSize, genres: genre, countries: country)
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
}
