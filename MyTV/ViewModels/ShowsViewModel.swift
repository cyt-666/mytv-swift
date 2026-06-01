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

    func load() async {
        isLoading = true
        defer { isLoading = false }

        do {
            switch selectedTab {
            case .trending:
                let result = try await ShowAPI.trending(limit: 20)
                items = result.map(\.show)
            case .popular:
                items = try await ShowAPI.popular(limit: 20)
            case .anticipated:
                let result = try await ShowAPI.anticipated(limit: 20)
                items = result.map(\.show)
            }
        } catch {
            print("加载剧集列表失败: \(error)")
        }
    }
}
