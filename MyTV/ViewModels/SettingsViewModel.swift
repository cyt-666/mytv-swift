import Foundation

@Observable
@MainActor
final class SettingsViewModel {
    var isLoading = false
    var moviePilotHost = MoviePilotSettingsStore.defaultHost
    var moviePilotAPIKey = ""
    var moviePilotNotificationsEnabled = false
    var moviePilotNotificationCategories = MoviePilotNotificationCategory.defaultEnabled
    var moviePilotSubscriptionPreferences = MoviePilotSubscriptionPreferences.default
    var moviePilotSites: [MoviePilotConfiguredSite] = []
    var moviePilotRuleGroups: [MoviePilotRuleGroup] = []
    var isTestingMoviePilot = false
    var isSavingMoviePilot = false
    var isLoadingSubscriptionOptions = false
    var moviePilotMessage: String?
    var moviePilotErrorMessage: String?
    var availableMoviePilotTools: Set<String> = []

    var isMoviePilotConfigured: Bool {
        !moviePilotHost.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !moviePilotAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var moviePilotConnectionSummary: String {
        if availableMoviePilotTools.isEmpty {
            return isMoviePilotConfigured ? L10n.string("尚未测试连接") : L10n.string("未配置")
        }
        let missing = MoviePilotConnectionResult.requiredTools.subtracting(availableMoviePilotTools).sorted()
        if missing.isEmpty {
            return L10n.string("连接正常")
        }
        return L10n.string("连接成功，缺少工具：%@", missing.joined(separator: ", "))
    }

    func loadMoviePilotSettings() {
        moviePilotHost = MoviePilotSettingsStore.host()
        moviePilotAPIKey = (try? MoviePilotSettingsStore.apiKey()) ?? ""
        moviePilotNotificationsEnabled = MoviePilotSettingsStore.notificationsEnabled()
        moviePilotNotificationCategories = MoviePilotSettingsStore.notificationCategories()
        moviePilotSubscriptionPreferences = MoviePilotSettingsStore.subscriptionPreferences()
    }

    func saveMoviePilotSettings() async {
        guard !isSavingMoviePilot else { return }
        isSavingMoviePilot = true
        moviePilotMessage = nil
        moviePilotErrorMessage = nil
        defer { isSavingMoviePilot = false }

        do {
            MoviePilotSettingsStore.setHost(moviePilotHost)
            try MoviePilotSettingsStore.setAPIKey(moviePilotAPIKey)
            moviePilotHost = MoviePilotSettingsStore.host()
            moviePilotAPIKey = (try? MoviePilotSettingsStore.apiKey()) ?? ""
            await MoviePilotAPIClient.shared.invalidateToolCatalog()
            await MoviePilotMediaStatusProvider.shared.invalidate()
            moviePilotMessage = L10n.string("MoviePilot 设置已保存")
            MoviePilotNotificationService.shared.restartIfNeeded()
            await loadSubscriptionOptions()
        } catch {
            moviePilotErrorMessage = error.localizedDescription
        }
    }

    func testMoviePilotConnection() async {
        guard !isTestingMoviePilot else { return }
        isTestingMoviePilot = true
        moviePilotMessage = nil
        moviePilotErrorMessage = nil
        defer { isTestingMoviePilot = false }

        let host = moviePilotHost.trimmingCharacters(in: .whitespacesAndNewlines)
        let apiKey = moviePilotAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !host.isEmpty, !apiKey.isEmpty else {
            moviePilotErrorMessage = L10n.string("请填写 MoviePilot 地址和 API Key")
            return
        }

        do {
            let result = try await MoviePilotAPIClient.shared.validateConnection(host: host, apiKey: apiKey)
            availableMoviePilotTools = result.availableTools
            moviePilotMessage = result.hasRequiredTools ? L10n.string("MoviePilot 连接正常") : moviePilotConnectionSummary
        } catch {
            availableMoviePilotTools = []
            moviePilotErrorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    func clearMoviePilotSettings() {
        do {
            try MoviePilotSettingsStore.clearConnection()
            loadMoviePilotSettings()
            availableMoviePilotTools = []
            moviePilotSites = []
            moviePilotRuleGroups = []
            moviePilotMessage = L10n.string("MoviePilot 设置已清除")
            moviePilotErrorMessage = nil
            MoviePilotNotificationService.shared.stop()
            Task {
                await MoviePilotAPIClient.shared.invalidateToolCatalog()
                await MoviePilotMediaStatusProvider.shared.invalidate()
            }
        } catch {
            moviePilotErrorMessage = error.localizedDescription
        }
    }

    func setMoviePilotNotificationsEnabled(_ enabled: Bool) async {
        moviePilotMessage = nil
        moviePilotErrorMessage = nil

        if enabled {
            guard isMoviePilotConfigured else {
                moviePilotErrorMessage = L10n.string("请先保存 MoviePilot 连接设置")
                moviePilotNotificationsEnabled = false
                MoviePilotSettingsStore.setNotificationsEnabled(false)
                return
            }

            let granted = await MoviePilotNotificationService.shared.requestAuthorization()
            guard granted else {
                moviePilotErrorMessage = L10n.string("系统通知权限未开启")
                moviePilotNotificationsEnabled = false
                MoviePilotSettingsStore.setNotificationsEnabled(false)
                MoviePilotNotificationService.shared.restartIfNeeded()
                return
            }
        }

        MoviePilotSettingsStore.setNotificationsEnabled(enabled)
        moviePilotNotificationsEnabled = enabled
        MoviePilotNotificationService.shared.restartIfNeeded()
        moviePilotMessage = enabled ? L10n.string("MoviePilot 通知已开启") : L10n.string("MoviePilot 通知已关闭")
    }

    func setMoviePilotNotificationCategory(_ category: MoviePilotNotificationCategory, enabled: Bool) {
        if enabled {
            moviePilotNotificationCategories.insert(category)
        } else {
            moviePilotNotificationCategories.remove(category)
        }
        MoviePilotSettingsStore.setNotificationCategories(moviePilotNotificationCategories)
        MoviePilotNotificationService.shared.restartIfNeeded()
        moviePilotMessage = L10n.string("通知类型已更新")
    }

    func saveMoviePilotSubscriptionPreferences() {
        MoviePilotSettingsStore.setSubscriptionPreferences(moviePilotSubscriptionPreferences)
        moviePilotMessage = "MoviePilot 订阅偏好已保存"
        moviePilotErrorMessage = nil
    }

    func loadSubscriptionOptions() async {
        guard isMoviePilotConfigured, !isLoadingSubscriptionOptions else {
            if !isMoviePilotConfigured {
                moviePilotSites = []
                moviePilotRuleGroups = []
            }
            return
        }

        isLoadingSubscriptionOptions = true
        defer { isLoadingSubscriptionOptions = false }

        do {
            async let sites = MoviePilotAPIClient.shared.fetchConfiguredSites()
            async let ruleGroups = MoviePilotAPIClient.shared.fetchRuleGroups()
            moviePilotSites = try await sites
            moviePilotRuleGroups = try await ruleGroups
        } catch {
            moviePilotSites = []
            moviePilotRuleGroups = []
            moviePilotErrorMessage = (error as? LocalizedError)?.errorDescription
                ?? error.localizedDescription
        }
    }
}
