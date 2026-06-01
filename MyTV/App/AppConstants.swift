import Foundation

enum AppConstants {
    // MARK: - Trakt API
    static let clientID: String = {
        guard let value = Bundle.main.object(forInfoDictionaryKey: "TraktClientID") as? String,
              !value.isEmpty,
              !value.hasPrefix("$(")
        else {
            fatalError("Missing TRAKT_CLIENT_ID build setting. Pass TRAKT_CLIENT_ID=<client_id> when building.")
        }
        return value
    }()
    static let redirectURI = "mytv://oauth/callback"
    static let callbackScheme = "mytv"
    static let apiBaseURL = "https://api.trakt.tv"
    static let traktHost = "https://trakt.tv"
    static let tmdbImageBase = "https://image.tmdb.org/t/p/"

    // MARK: - Cache TTL (milliseconds matching Rust source)
    enum CacheTTL {
        static let long: TimeInterval = 30 * 24 * 60 * 60            // 30 days
        static let short: TimeInterval = 24 * 60 * 60                // 1 day
        static let translation: TimeInterval = 7 * 24 * 60 * 60      // 7 days
        static let apiList: TimeInterval = 4 * 60 * 60               // 4 hours
        static let staleWhileRevalidate: TimeInterval = 60 * 60      // 1 hour
        static let staleWhileRevalidateUser: TimeInterval = 5 * 60   // 5 minutes
    }

    // MARK: - Translation
    static let translationMaxConcurrent = 3
    static let translationTimeout: TimeInterval = 8
    static let translationPendingTimeout: TimeInterval = 5
    static let translationFailureCacheDuration: TimeInterval = 5 * 60

    // MARK: - Window
    static let defaultWindowWidth: Double = 1200
    static let defaultWindowHeight: Double = 800
    static let sidebarMinWidth: CGFloat = 210
    static let sidebarIdealWidth: CGFloat = 232
    static let sidebarMaxWidth: CGFloat = 248
}
