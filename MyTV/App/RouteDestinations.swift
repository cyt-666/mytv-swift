import SwiftUI

struct RouteDestinationView: View {
    let route: Route

    var body: some View {
        switch route {
        case .movies:
            MoviesView()
        case .shows:
            ShowsView()
        case .browse:
            BrowseView()
        case .upNext:
            UpNextView()
        case .watchlist:
            WatchlistView()
        case .history:
            HistoryView()
        case .collection:
            CollectionView()
        case .movieDetail(let id):
            MovieDetailView(movieId: id)
        case .showDetail(let id):
            ShowDetailView(showId: id)
        case .seasonDetail(let showId, let seasonNumber):
            SeasonDetailView(showId: showId, seasonNumber: seasonNumber)
        case .episodeDetail(let showId, let seasonNumber, let episodeNumber):
            EpisodeDetailView(showId: showId, seasonNumber: seasonNumber, episodeNumber: episodeNumber)
        case .search(let query):
            SearchView(query: query)
        case .recommendations(let type):
            RecommendationsView(type: type)
        case .profile:
            ProfileView()
        case .settings:
            SettingsView()
        }
    }
}

extension View {
    func appRouteDestinations() -> some View {
        navigationDestination(for: Route.self) { route in
            RouteDestinationView(route: route)
        }
    }
}
