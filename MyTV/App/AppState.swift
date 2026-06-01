import Foundation
import SwiftUI

enum SidebarSection: String, CaseIterable, Identifiable, Hashable {
    case home = "首页"
    case movies = "电影"
    case shows = "电视剧"
    case browse = "分类"
    case upNext = "待看"
    case watchlist = "观看清单"
    case history = "观看历史"
    case collection = "我的片库"
    case calendar = "剧集日历"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .home: return "house.fill"
        case .movies: return "film.fill"
        case .shows: return "tv.fill"
        case .browse: return "square.grid.2x2.fill"
        case .upNext: return "clock.fill"
        case .watchlist: return "bookmark.fill"
        case .history: return "clock.arrow.circlepath"
        case .collection: return "folder.fill"
        case .calendar: return "calendar"
        }
    }

    var isDiscovery: Bool {
        switch self {
        case .home, .movies, .shows, .browse: return true
        default: return false
        }
    }
}

enum Route: Hashable {
    case movieDetail(id: Int)
    case showDetail(id: Int)
    case seasonDetail(showId: Int, seasonNumber: Int)
    case episodeDetail(showId: Int, seasonNumber: Int, episodeNumber: Int)
    case search(query: String)
    case recommendations(type: String)
    case profile
    case settings
}

@Observable
final class AppState {
    var selectedSection: SidebarSection? = .home
    var navigationPath = NavigationPath()
    var searchQuery = ""
    var homeFanartURL: String?

    func navigate(to route: Route) {
        navigationPath.append(route)
    }

    func navigateToSection(_ section: SidebarSection) {
        navigationPath = NavigationPath()
        selectedSection = section
    }

    func goBack() {
        guard !navigationPath.isEmpty else { return }
        navigationPath.removeLast()
    }
}
