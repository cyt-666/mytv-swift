import SwiftUI

struct ContentView: View {
    @Environment(AppState.self) private var appState
    @State private var authService = AuthService.shared

    var body: some View {
        @Bindable var state = appState

        if authService.isLoggedIn {
            ZStack {
                WindowSurfaceBackground()

                NavigationSplitView {
                    SidebarView()
                        .navigationSplitViewColumnWidth(
                            min: AppConstants.sidebarMinWidth,
                            ideal: AppConstants.sidebarIdealWidth,
                            max: AppConstants.sidebarMaxWidth
                        )
                } detail: {
                    NavigationStack(path: $state.navigationPath) {
                        detailContent
                            .navigationDestination(for: Route.self) { route in
                                destinationView(for: route)
                            }
                    }
                }
                .toolbarBackground(.hidden, for: .windowToolbar)
                .onChange(of: appState.selectedSection) { _, _ in
                    appState.navigationPath = NavigationPath()
                }
            }
        } else {
            LoginWebView()
        }
    }

    @ViewBuilder
    private var detailContent: some View {
        switch appState.selectedSection {
        case .home:
            HomeView()
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
        case .calendar:
            CalendarView()
        case .none:
            Text("请选择一个页面")
        }
    }

    @ViewBuilder
    private func destinationView(for route: Route) -> some View {
        switch route {
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

private struct WindowSurfaceBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            Rectangle().fill(.ultraThinMaterial)

            if colorScheme == .dark {
                Color.black.opacity(0.18)

                LinearGradient(
                    colors: [
                        .white.opacity(0.05),
                        .clear,
                        .black.opacity(0.12)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            } else {
                Color.white.opacity(0.16)

                LinearGradient(
                    colors: [
                        .white.opacity(0.20),
                        .clear,
                        .black.opacity(0.03)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        }
        .ignoresSafeArea()
    }
}
