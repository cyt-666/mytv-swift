import Foundation

@Observable
@MainActor
final class SettingsViewModel {
    var isLoading = false
    var moviePilotHost = MoviePilotSettingsStore.defaultHost
    var moviePilotAPIKey = ""
    var moviePilotNotificationsEnabled = false
    var isTestingMoviePilot = false
    var isSavingMoviePilot = false
    var moviePilotMessage: String?
    var moviePilotErrorMessage: String?
    var availableMoviePilotTools: Set<String> = []

    var isMoviePilotConfigured: Bool {
        !moviePilotHost.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !moviePilotAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var moviePilotConnectionSummary: String {
        if availableMoviePilotTools.isEmpty {
            return isMoviePilotConfigured ? "尚未测试连接" : "未配置"
        }
        let required: Set<String> = [
            "add_subscribe",
            "query_subscribes",
            "query_library_exists",
            "query_download_tasks"
        ]
        let missing = required.subtracting(availableMoviePilotTools).sorted()
        if missing.isEmpty {
            return "连接正常"
        }
        return "连接成功，缺少工具：\(missing.joined(separator: ", "))"
    }

    func loadMoviePilotSettings() {
        moviePilotHost = MoviePilotSettingsStore.host()
        moviePilotAPIKey = (try? MoviePilotSettingsStore.apiKey()) ?? ""
        moviePilotNotificationsEnabled = MoviePilotSettingsStore.notificationsEnabled()
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
            moviePilotMessage = "MoviePilot 设置已保存"
            MoviePilotNotificationService.shared.restartIfNeeded()
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
            moviePilotErrorMessage = "请填写 MoviePilot 地址和 API Key"
            return
        }

        do {
            let result = try await MoviePilotAPIClient.shared.validateConnection(host: host, apiKey: apiKey)
            availableMoviePilotTools = result.availableTools
            moviePilotMessage = result.hasRequiredTools ? "MoviePilot 连接正常" : moviePilotConnectionSummary
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
            moviePilotMessage = "MoviePilot 设置已清除"
            moviePilotErrorMessage = nil
            MoviePilotNotificationService.shared.stop()
        } catch {
            moviePilotErrorMessage = error.localizedDescription
        }
    }

    func setMoviePilotNotificationsEnabled(_ enabled: Bool) async {
        moviePilotMessage = nil
        moviePilotErrorMessage = nil

        if enabled {
            guard isMoviePilotConfigured else {
                moviePilotErrorMessage = "请先保存 MoviePilot 连接设置"
                moviePilotNotificationsEnabled = false
                MoviePilotSettingsStore.setNotificationsEnabled(false)
                return
            }

            let granted = await MoviePilotNotificationService.shared.requestAuthorization()
            guard granted else {
                moviePilotErrorMessage = "系统通知权限未开启"
                moviePilotNotificationsEnabled = false
                MoviePilotSettingsStore.setNotificationsEnabled(false)
                MoviePilotNotificationService.shared.restartIfNeeded()
                return
            }
        }

        MoviePilotSettingsStore.setNotificationsEnabled(enabled)
        moviePilotNotificationsEnabled = enabled
        MoviePilotNotificationService.shared.restartIfNeeded()
        moviePilotMessage = enabled ? "入库通知已开启" : "入库通知已关闭"
    }
}
