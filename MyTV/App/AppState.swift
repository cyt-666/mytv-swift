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
    case moviePilot = "MoviePilot"

    var id: String { rawValue }

    var titleKey: LocalizedStringKey {
        switch self {
        case .home: return "首页"
        case .movies: return "电影"
        case .shows: return "电视剧"
        case .browse: return "分类"
        case .upNext: return "待看"
        case .watchlist: return "观看清单"
        case .history: return "观看历史"
        case .collection: return "我的片库"
        case .calendar: return "剧集日历"
        case .moviePilot: return "媒体助手"
        }
    }

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
        case .moviePilot: return "bolt.horizontal.circle.fill"
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
    case movies
    case shows
    case browse
    case upNext
    case watchlist
    case history
    case collection
    case movieDetail(id: Int)
    case showDetail(id: Int)
    case seasonDetail(showId: Int, seasonNumber: Int)
    case episodeDetail(showId: Int, seasonNumber: Int, episodeNumber: Int)
    case search(query: String)
    case recommendations(type: String)
    case profile
    case settings
}

@MainActor
@Observable
final class AppRouter {
    var path: [Route] = []

    func navigate(to route: Route) {
        path.append(route)
    }

    func reset() {
        path = []
    }
}

@MainActor
@Observable
final class AppState {
    var selectedSection: SidebarSection? = .home
    var navigationPath: [Route] = []
    var searchQuery = ""
    var homeFanartURL: String?
    var router: AppRouter?
    var appLanguage: AppLanguage
    var needsLanguageSelection: Bool
    var isMediaAssistantConfigured = false

    init() {
        let storedLanguageCode = UserDefaults.standard.string(forKey: AppLanguageStorage.appLanguage)
        appLanguage = storedLanguageCode.flatMap(AppLanguage.init(rawValue:)) ?? .preferredSystemLanguage
        needsLanguageSelection = !UserDefaults.standard.bool(forKey: AppLanguageStorage.didChooseLanguage)
    }

    func navigate(to route: Route) {
        if let router {
            router.navigate(to: route)
        } else {
            navigationPath.append(route)
        }
    }

    func navigateToSection(_ section: SidebarSection) {
        navigationPath = []
        router?.reset()
        selectedSection = section
    }

    func refreshMediaAssistantConfiguration() {
        isMediaAssistantConfigured = MoviePilotSettingsStore.hasConnectionConfiguration()
        if !isMediaAssistantConfigured, selectedSection == .moviePilot {
            navigateToSection(.home)
        }
    }

    func goBack() {
        guard !navigationPath.isEmpty else { return }
        navigationPath.removeLast()
    }

    func setAppLanguage(_ language: AppLanguage) {
        appLanguage = language
        needsLanguageSelection = false
        UserDefaults.standard.set(language.rawValue, forKey: AppLanguageStorage.appLanguage)
        UserDefaults.standard.set(true, forKey: AppLanguageStorage.didChooseLanguage)
    }
}
