import Foundation

@MainActor
enum MoviePilotSettingsStore {
    static let defaultHost = "http://localhost:3001"

    private static let hostKey = "moviepilot.host"
    private static let notificationsEnabledKey = "moviepilot.notificationsEnabled"
    private static let notificationCategoriesKey = "moviepilot.notificationCategories"
    private static let lastMessageIdKey = "moviepilot.lastMessageId"
    private static let subscriptionPreferencesKey = "moviepilot.subscriptionPreferences"
    private static let keychainService = "com.mytv.moviepilot"
    private static let apiKeyAccount = "apiKey"

    static func host() -> String {
        guard let data = CacheService.getConfig(key: hostKey),
              let value = String(data: data, encoding: .utf8),
              !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return defaultHost
        }
        return value
    }

    static func configuredHost() -> String? {
        guard let data = CacheService.getConfig(key: hostKey),
              let value = String(data: data, encoding: .utf8) else {
            return nil
        }

        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    static func setHost(_ host: String) {
        let trimmed = host.trimmingCharacters(in: .whitespacesAndNewlines)
        let value = trimmed.isEmpty ? defaultHost : trimmed
        CacheService.setConfig(key: hostKey, value: Data(value.utf8))
        MoviePilotResourceSearchCache.clearAll()
    }

    static func apiKey() throws -> String? {
        try KeychainService.read(service: keychainService, account: apiKeyAccount)
    }

    static func setAPIKey(_ apiKey: String) throws {
        let trimmed = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            try KeychainService.delete(service: keychainService, account: apiKeyAccount)
        } else {
            try KeychainService.save(trimmed, service: keychainService, account: apiKeyAccount)
        }
        MoviePilotResourceSearchCache.clearAll()
    }

    static func clearConnection() throws {
        CacheService.setConfig(key: hostKey, value: Data())
        CacheService.setConfig(key: notificationsEnabledKey, value: Data("false".utf8))
        setNotificationCategories(MoviePilotNotificationCategory.defaultEnabled)
        CacheService.setConfig(key: lastMessageIdKey, value: Data("0".utf8))
        try KeychainService.delete(service: keychainService, account: apiKeyAccount)
        MoviePilotResourceSearchCache.clearAll()
    }

    static func notificationsEnabled() -> Bool {
        guard let data = CacheService.getConfig(key: notificationsEnabledKey),
              let value = String(data: data, encoding: .utf8) else {
            return false
        }
        return value == "true"
    }

    static func setNotificationsEnabled(_ enabled: Bool) {
        CacheService.setConfig(key: notificationsEnabledKey, value: Data((enabled ? "true" : "false").utf8))
    }

    static func notificationCategories() -> Set<MoviePilotNotificationCategory> {
        guard let data = CacheService.getConfig(key: notificationCategoriesKey) else {
            return MoviePilotNotificationCategory.defaultEnabled
        }

        if let categories = try? JSONDecoder().decode(Set<MoviePilotNotificationCategory>.self, from: data),
           !categories.isEmpty {
            return categories
        }

        if let rawValues = try? JSONDecoder().decode([String].self, from: data) {
            let categories = Set(rawValues.compactMap(MoviePilotNotificationCategory.init(rawValue:)))
            if !categories.isEmpty {
                return categories
            }
        }

        return MoviePilotNotificationCategory.defaultEnabled
    }

    static func setNotificationCategories(_ categories: Set<MoviePilotNotificationCategory>) {
        let value = categories.isEmpty ? MoviePilotNotificationCategory.defaultEnabled : categories
        if let data = try? JSONEncoder().encode(value) {
            CacheService.setConfig(key: notificationCategoriesKey, value: data)
        }
    }

    static func lastMessageId() -> Int? {
        guard let data = CacheService.getConfig(key: lastMessageIdKey),
              let value = String(data: data, encoding: .utf8),
              let id = Int(value),
              id > 0 else {
            return nil
        }
        return id
    }

    static func setLastMessageId(_ id: Int) {
        CacheService.setConfig(key: lastMessageIdKey, value: Data(String(id).utf8))
    }

    static func hasConnectionConfiguration() -> Bool {
        guard configuredHost() != nil,
              let apiKey = try? apiKey()?.trimmingCharacters(in: .whitespacesAndNewlines),
              !apiKey.isEmpty else {
            return false
        }
        return true
    }

    static func subscriptionPreferences() -> MoviePilotSubscriptionPreferences {
        guard let data = CacheService.getConfig(key: subscriptionPreferencesKey),
              let preferences = try? JSONDecoder().decode(
                MoviePilotSubscriptionPreferences.self,
                from: data
              ) else {
            return .default
        }
        return preferences
    }

    static func setSubscriptionPreferences(_ preferences: MoviePilotSubscriptionPreferences) {
        guard let data = try? JSONEncoder().encode(preferences) else { return }
        CacheService.setConfig(key: subscriptionPreferencesKey, value: data)
    }

    static func currentConfiguration() throws -> (host: String, apiKey: String)? {
        guard let host = configuredHost(),
              let storedAPIKey = try apiKey() else {
            return nil
        }

        let apiKey = storedAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !apiKey.isEmpty else {
            return nil
        }

        return (host, apiKey)
    }
}
