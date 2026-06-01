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

    func load() async {
        isLoading = true
        defer { isLoading = false }

        do {
            switch selectedTab {
            case .trending:
                let result = try await MovieAPI.trending(limit: 20)
                items = result.map(\.movie)
            case .popular:
                items = try await MovieAPI.popular(limit: 20)
            case .anticipated:
                let result = try await MovieAPI.anticipated(limit: 20)
                items = result.map(\.movie)
            }
        } catch {
            print("加载电影列表失败: \(error)")
        }
    }
}
