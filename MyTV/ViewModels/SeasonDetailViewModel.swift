import Foundation

@Observable
@MainActor
final class SeasonDetailViewModel {
    let showId: Int
    let seasonNumber: Int
    var show: ShowDetailsDTO?
    var season: SeasonDTO?
    var episodes: [EpisodeDTO] = []
    var episodeStates: [Int: MoviePilotEpisodeState] = [:]
    var isLoading = false
    var isLoadingMoviePilot = false
    var moviePilotErrorMessage: String?

    var moviePilotTarget: MoviePilotMediaTarget? {
        show.map(MoviePilotMediaTarget.show)
    }

    var statusSummary: MoviePilotEpisodeStateSummary {
        MoviePilotEpisodeStateSummary(states: episodeStates.values)
    }

    var isMoviePilotConfigured: Bool {
        (try? MoviePilotSettingsStore.currentConfiguration()) != nil
    }

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
            async let showResult = ShowAPI.details(id: showId)
            episodes = try await episodesResult
            let seasons = try await seasonsResult
            show = try await showResult
            season = seasons.first { $0.number == seasonNumber }
            await loadMoviePilotStatus()
        } catch {
            print("加载季度详情失败: \(error)")
        }
    }

    func loadMoviePilotStatus(forceRefresh: Bool = false) async {
        guard seasonNumber > 0,
              isMoviePilotConfigured,
              let target = moviePilotTarget,
              target.tmdbId != nil else {
            episodeStates = [:]
            moviePilotErrorMessage = nil
            return
        }
        guard !isLoadingMoviePilot else { return }

        isLoadingMoviePilot = true
        moviePilotErrorMessage = nil
        defer { isLoadingMoviePilot = false }

        do {
            let status = try await MoviePilotMediaStatusProvider.shared.status(
                for: target,
                forceRefresh: forceRefresh
            )
            episodeStates = MoviePilotEpisodeStateResolver.states(
                for: episodes,
                status: status
            )
        } catch {
            episodeStates = [:]
            moviePilotErrorMessage = (error as? LocalizedError)?.errorDescription
                ?? error.localizedDescription
        }
    }
}
