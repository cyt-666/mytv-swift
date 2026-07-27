import SwiftUI

#if os(iOS)
import UIKit

enum IOSAppTab: String, CaseIterable, Identifiable, Hashable {
    case home
    case discover
    case calendar
    case moviePilot
    case profile

    var id: String { rawValue }

    var titleKey: LocalizedStringKey {
        switch self {
        case .home: return "首页"
        case .discover: return "发现"
        case .calendar: return "日历"
        case .moviePilot: return "媒体助手"
        case .profile: return "我的"
        }
    }

    var icon: String {
        switch self {
        case .home: return "house.fill"
        case .discover: return "square.grid.2x2.fill"
        case .calendar: return "calendar"
        case .moviePilot: return "bolt.horizontal.circle.fill"
        case .profile: return "person.crop.circle.fill"
        }
    }
}

struct IOSRootView: View {
    @State private var authService = AuthService.shared

    var body: some View {
        rootContent
            .background {
                WindowAccessor { window in
                    authService.updatePresentationAnchor(window)
                }
                .frame(width: 0, height: 0)
            }
    }

    @ViewBuilder
    private var rootContent: some View {
        if authService.isLoggedIn {
            if UIDevice.current.userInterfaceIdiom == .pad {
                IOSPadRootView()
            } else {
                IOSTabRootView()
            }
        } else {
            LoginWebView()
        }
    }
}

private struct IOSTabRootView: View {
    @Environment(AppState.self) private var appState
    @State private var selectedTab: IOSAppTab = .home
    @State private var routerStore = IOSTabRouterStore()

    private var availableTabs: [IOSAppTab] {
        IOSAppTab.allCases.filter { tab in
            tab != .moviePilot || appState.isMediaAssistantConfigured
        }
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            ForEach(availableTabs) { tab in
                IOSTabNavigationRoot(tab: tab, router: routerStore.router(for: tab))
                    .tabItem {
                        Label(tab.titleKey, systemImage: tab.icon)
                    }
                    .tag(tab)
            }
        }
        .onAppear {
            if selectedTab == .moviePilot, !appState.isMediaAssistantConfigured {
                selectedTab = .home
            }
            appState.router = routerStore.router(for: selectedTab)
        }
        .onChange(of: selectedTab) { _, tab in
            appState.router = routerStore.router(for: tab)
        }
        .onChange(of: appState.isMediaAssistantConfigured) { _, isConfigured in
            if !isConfigured, selectedTab == .moviePilot {
                selectedTab = .home
                appState.router = routerStore.router(for: .home)
            }
        }
    }
}

@MainActor
private final class IOSTabRouterStore {
    private let home = AppRouter()
    private let discover = AppRouter()
    private let calendar = AppRouter()
    private let moviePilot = AppRouter()
    private let profile = AppRouter()

    func router(for tab: IOSAppTab) -> AppRouter {
        switch tab {
        case .home: return home
        case .discover: return discover
        case .calendar: return calendar
        case .moviePilot: return moviePilot
        case .profile: return profile
        }
    }
}

private struct IOSTabNavigationRoot: View {
    @Environment(AppState.self) private var appState
    let tab: IOSAppTab
    let router: AppRouter

    var body: some View {
        @Bindable var router = router

        NavigationStack(path: $router.path) {
            tabContent
                .navigationTitle(tab.titleKey)
                .appRouteDestinations()
                .toolbar {
                    ToolbarItemGroup(placement: .topBarTrailing) {
                        if tab == .profile {
                            Button {
                                appState.navigate(to: .settings)
                            } label: {
                                Image(systemName: "gearshape")
                            }
                            .accessibilityLabel("设置")
                        } else {
                            Button {
                                appState.navigate(to: .search(query: ""))
                            } label: {
                                Image(systemName: "magnifyingglass")
                            }
                            .accessibilityLabel("搜索")
                        }
                    }
                }
        }
        .environment(router)
    }

    @ViewBuilder
    private var tabContent: some View {
        switch tab {
        case .home:
            HomeView()
        case .discover:
            IOSDiscoverView()
        case .calendar:
            CalendarView()
        case .moviePilot:
            MoviePilotCenterView()
        case .profile:
            IOSAccountView()
        }
    }
}

private struct IOSPadRootView: View {
    @Environment(AppState.self) private var appState
    @State private var router = AppRouter()

    var body: some View {
        @Bindable var state = appState
        @Bindable var router = router

        NavigationSplitView {
            SidebarView()
        } detail: {
            NavigationStack(path: $router.path) {
                IOSSectionContent(section: state.selectedSection)
                    .appRouteDestinations()
            }
        }
        .environment(router)
        .onAppear {
            appState.router = router
        }
        .onChange(of: appState.selectedSection) { _, _ in
            router.reset()
        }
    }
}

private struct IOSSectionContent: View {
    let section: SidebarSection?

    var body: some View {
        switch section {
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
        case .moviePilot:
            MoviePilotCenterView()
        case .none:
            ContentUnavailableView("请选择一个页面", systemImage: "sidebar.left")
        }
    }
}

private struct IOSDiscoverView: View {
    var body: some View {
        List {
            NavigationLink(value: Route.movies) {
                Label("电影", systemImage: "film.fill")
            }

            NavigationLink(value: Route.shows) {
                Label("电视剧", systemImage: "tv.fill")
            }

            NavigationLink(value: Route.browse) {
                Label("分类", systemImage: "square.grid.2x2.fill")
            }
        }
    }
}

private struct IOSAccountView: View {
    var body: some View {
        List {
            Section("账号") {
                NavigationLink(value: Route.profile) {
                    Label("个人资料", systemImage: "person.crop.circle")
                }

                NavigationLink(value: Route.settings) {
                    Label("设置", systemImage: "gear")
                }
            }

            Section("媒体") {
                NavigationLink(value: Route.upNext) {
                    Label("待看", systemImage: "clock.fill")
                }

                NavigationLink(value: Route.watchlist) {
                    Label("观看清单", systemImage: "bookmark.fill")
                }

                NavigationLink(value: Route.history) {
                    Label("观看历史", systemImage: "clock.arrow.circlepath")
                }

                NavigationLink(value: Route.collection) {
                    Label("我的片库", systemImage: "folder.fill")
                }
            }

        }
    }
}
#endif
