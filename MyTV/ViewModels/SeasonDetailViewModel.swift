import Foundation

@Observable
@MainActor
final class SeasonDetailViewModel {
    let showId: Int
    let seasonNumber: Int
    var season: SeasonDTO?
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
            async let episodesResult = ShowAPI.seasonEpisodes(showId: showId, seasonNumber: seasonNumber)
            async let seasonsResult = ShowAPI.seasons(id: showId)
            episodes = try await episodesResult
            let seasons = try await seasonsResult
            season = seasons.first { $0.number == seasonNumber }
        } catch {
            print("加载季度详情失败: \(error)")
        }
    }
}
