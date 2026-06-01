import Foundation

@MainActor enum TraktEndpoint {
    // Auth
    case authorize
    case getToken
    case refreshToken
    case revokeToken

    // Movies
    case movieTrending(page: Int, limit: Int, genres: String?, countries: String?)
    case moviePopular(page: Int, limit: Int, genres: String?, countries: String?)
    case movieAnticipated(page: Int, limit: Int, genres: String?, countries: String?)
    case movieDetails(id: Int)
    case movieTranslation(id: Int, language: String)
    case movieWatched(period: String, page: Int, limit: Int, genres: String?, countries: String?)
    case movieCollected(period: String, page: Int, limit: Int, genres: String?, countries: String?)

    // Shows
    case showTrending(page: Int, limit: Int, genres: String?, countries: String?)
    case showPopular(page: Int, limit: Int, genres: String?, countries: String?)
    case showAnticipated(page: Int, limit: Int, genres: String?, countries: String?)
    case showDetails(id: Int)
    case showTranslation(id: Int, language: String)
    case showSeasons(id: Int)
    case showSeasonTranslation(id: Int, seasonNumber: Int, language: String)
    case showSeasonEpisodes(id: Int, seasonNumber: Int)
    case showEpisodeDetails(id: Int, seasonNumber: Int, episodeNumber: Int)
    case showEpisodeTranslation(id: Int, seasonNumber: Int, episodeNumber: Int, language: String)
    case showProgress(id: Int)
    case showWatched(period: String, page: Int, limit: Int, genres: String?, countries: String?)
    case showCollected(period: String, page: Int, limit: Int, genres: String?, countries: String?)

    // Search
    case search(query: String, page: Int, limit: Int)

    // Sync
    case addToCollection
    case removeFromCollection
    case addToWatchlist
    case removeFromWatchlist
    case addToHistory

    // User
    case userProfile
    case userWatched(type: String)
    case userStats
    case userCollection(type: String)
    case userWatchlist(type: String)
    case userHistory(type: String?, page: Int, limit: Int)

    // Calendars
    case calendarShows(startDate: String, days: Int)
    case calendarMyShows(startDate: String, days: Int)
    case calendarMovies(startDate: String, days: Int)
    case calendarNewShows(startDate: String, days: Int)
    case calendarSeasonPremieres(startDate: String, days: Int)

    // Recommendations
    case movieRecommendations
    case showRecommendations

    var method: String {
        switch self {
        case .authorize: return "GET"
        case .getToken, .refreshToken, .revokeToken: return "POST"
        case .addToCollection, .removeFromCollection,
             .addToWatchlist, .removeFromWatchlist,
             .addToHistory: return "POST"
        default: return "GET"
        }
    }

    var uri: String {
        switch self {
        // Auth
        case .authorize: return "/oauth/authorize"
        case .getToken, .refreshToken: return "/oauth/token"
        case .revokeToken: return "/oauth/revoke"

        // Movies
        case .movieTrending: return "/movies/trending"
        case .moviePopular: return "/movies/popular"
        case .movieAnticipated: return "/movies/anticipated"
        case .movieDetails(let id): return "/movies/\(id)"
        case .movieTranslation(let id, let lang): return "/movies/\(id)/translations/\(lang)"
        case .movieWatched(let period, _, _, _, _): return "/movies/watched/\(period)"
        case .movieCollected(let period, _, _, _, _): return "/movies/collected/\(period)"

        // Shows
        case .showTrending: return "/shows/trending"
        case .showPopular: return "/shows/popular"
        case .showAnticipated: return "/shows/anticipated"
        case .showDetails(let id): return "/shows/\(id)"
        case .showTranslation(let id, let lang): return "/shows/\(id)/translations/\(lang)"
        case .showSeasons(let id): return "/shows/\(id)/seasons"
        case .showSeasonTranslation(let id, let num, let lang):
            return "/shows/\(id)/seasons/\(num)/translations/\(lang)"
        case .showSeasonEpisodes(let id, let num): return "/shows/\(id)/seasons/\(num)"
        case .showEpisodeDetails(let id, let s, let e):
            return "/shows/\(id)/seasons/\(s)/episodes/\(e)"
        case .showEpisodeTranslation(let id, let s, let e, let lang):
            return "/shows/\(id)/seasons/\(s)/episodes/\(e)/translations/\(lang)"
        case .showProgress(let id): return "/shows/\(id)/progress/watched"
        case .showWatched(let period, _, _, _, _): return "/shows/watched/\(period)"
        case .showCollected(let period, _, _, _, _): return "/shows/collected/\(period)"

        // Search
        case .search: return "/search/movie,show"

        // Sync
        case .addToCollection: return "/sync/collection"
        case .removeFromCollection: return "/sync/collection/remove"
        case .addToWatchlist: return "/sync/watchlist"
        case .removeFromWatchlist: return "/sync/watchlist/remove"
        case .addToHistory: return "/sync/history"

        // User
        case .userProfile: return "/users/settings"
        case .userWatched(let type): return "/users/me/watched/\(type)"
        case .userStats: return "/users/me/stats"
        case .userCollection(let type): return "/users/me/collection/\(type)"
        case .userWatchlist(let type): return "/users/me/watchlist/\(type)"
        case .userHistory(let type, _, _): return "/users/me/history\(type.map { "/\($0)" } ?? "")"

        // Calendars
        case .calendarShows(let start, let days): return "/calendars/all/shows/\(start)/\(days)"
        case .calendarMyShows(let start, let days): return "/calendars/my/shows/\(start)/\(days)"
        case .calendarMovies(let start, let days): return "/calendars/all/movies/\(start)/\(days)"
        case .calendarNewShows(let start, let days): return "/calendars/all/shows/new/\(start)/\(days)"
        case .calendarSeasonPremieres(let start, let days): return "/calendars/all/shows/premieres/\(start)/\(days)"

        // Recommendations
        case .movieRecommendations: return "/recommendations/movies"
        case .showRecommendations: return "/recommendations/shows"
        }
    }

    var defaultParams: [String: String]? {
        switch self {
        case .authorize:
            return [
                "client_id": AppConstants.clientID,
                "redirect_uri": AppConstants.redirectURI,
                "response_type": "code"
            ]
        case .movieTrending, .movieDetails, .movieTranslation:
            return ["extended": "full,images"]
        case .moviePopular, .movieAnticipated:
            return ["extended": "full"]
        case .movieWatched, .movieCollected:
            return ["extended": "full,images"]
        case .showDetails, .showTranslation:
            return ["extended": "full,images"]
        case .showPopular, .showAnticipated:
            return ["extended": "full"]
        case .showSeasons, .showSeasonEpisodes, .showEpisodeDetails:
            return ["extended": "full"]
        case .showProgress:
            return ["extended": "full"]
        case .showWatched, .showCollected:
            return ["extended": "full,images"]
        case .calendarShows, .calendarMyShows, .calendarMovies,
             .calendarNewShows, .calendarSeasonPremieres:
            return ["extended": "full,images"]
        case .movieRecommendations:
            return ["ignore_collected": "true", "ignore_watched": "true"]
        case .showRecommendations:
            return ["ignore_collected": "true", "ignore_watched": "true"]
        default:
            return nil
        }
    }

    var requiresAuth: Bool {
        switch self {
        case .authorize: return false
        case .getToken: return false
        case .movieTrending, .moviePopular, .movieAnticipated,
             .movieDetails, .movieTranslation, .movieWatched, .movieCollected:
            return false
        case .showTrending, .showPopular, .showAnticipated,
             .showDetails, .showTranslation, .showSeasons,
             .showSeasonTranslation, .showSeasonEpisodes,
             .showEpisodeDetails, .showEpisodeTranslation,
             .showWatched, .showCollected:
            return false
        case .search: return false
        default: return true
        }
    }

    func makePaginationParams(page: Int? = nil, limit: Int? = nil) -> [String: String] {
        var params: [String: String] = [:]
        if let page { params["page"] = "\(page)" }
        if let limit { params["limit"] = "\(limit)" }
        return params
    }

    func makeFilterParams(genres: String? = nil, countries: String? = nil) -> [String: String] {
        var params: [String: String] = [:]
        if let genres, !genres.isEmpty { params["genres"] = genres }
        if let countries, !countries.isEmpty { params["countries"] = countries }
        return params
    }

    static func makePagination(page: Int? = nil, limit: Int? = nil) -> [String: String] {
        var params: [String: String] = [:]
        if let page { params["page"] = "\(page)" }
        if let limit { params["limit"] = "\(limit)" }
        return params
    }

    static func makeFilter(genres: String? = nil, countries: String? = nil) -> [String: String] {
        var params: [String: String] = [:]
        if let genres, !genres.isEmpty { params["genres"] = genres }
        if let countries, !countries.isEmpty { params["countries"] = countries }
        return params
    }
}
