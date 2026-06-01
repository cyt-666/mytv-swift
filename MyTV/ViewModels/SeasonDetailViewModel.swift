import Foundation

@Observable
@MainActor
final class SeasonDetailViewModel {
    let showId: Int
    let seasonNumber: Int
    var episodes: [EpisodeDTO] = []
    var isLoading = false

    init(showId: Int, seasonNumber: Int) {
        self.showId = showId
        self.seasonNumber = seasonNumber
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }

        do {
            episodes = try await ShowAPI.seasonEpisodes(showId: showId, seasonNumber: seasonNumber)
        } catch {
            print("加载季度详情失败: \(error)")
        }
    }
}
