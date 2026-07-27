import Foundation
import UserNotifications
#if os(iOS)
import BackgroundTasks
#endif

@Observable
@MainActor
final class MoviePilotNotificationService {
    static let shared = MoviePilotNotificationService()
#if os(iOS)
    static let backgroundRefreshTaskIdentifier = "com.mytv.app.ios.moviepilot.refresh"
#endif

    private var pollingTask: Task<Void, Never>?

    private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined
    private(set) var lastErrorMessage: String?
    private(set) var isPolling = false

    private init() {}

    var authorizationStatusText: String {
        switch authorizationStatus {
        case .notDetermined:
            return L10n.string("未请求")
        case .denied:
            return L10n.string("已拒绝")
        case .authorized:
            return L10n.string("已允许")
        case .provisional:
            return L10n.string("临时允许")
        case .ephemeral:
            return L10n.string("临时会话")
        @unknown default:
            return L10n.string("未知")
        }
    }

    func configure() {
        Task {
            await refreshAuthorizationStatus()
            restartIfNeeded()
#if os(iOS)
            scheduleBackgroundRefreshIfNeeded()
#endif
        }
    }

    func refreshAuthorizationStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        authorizationStatus = settings.authorizationStatus
    }

    func requestAuthorization() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
            await refreshAuthorizationStatus()
            return granted
        } catch {
            lastErrorMessage = error.localizedDescription
            await refreshAuthorizationStatus()
            return false
        }
    }

    func restartIfNeeded() {
        pollingTask?.cancel()
        pollingTask = nil
        isPolling = false

        guard MoviePilotSettingsStore.notificationsEnabled(),
              authorizationStatus == .authorized || authorizationStatus == .provisional else {
            return
        }

        pollingTask = Task { [weak self] in
            await self?.pollLoop()
        }
        isPolling = true
#if os(iOS)
        scheduleBackgroundRefreshIfNeeded()
#endif
    }

    func stop() {
        pollingTask?.cancel()
        pollingTask = nil
        isPolling = false
    }

    private func pollLoop() async {
        while !Task.isCancelled {
            await pollOnce()
            do {
                try await Task.sleep(for: .seconds(60))
            } catch {
                break
            }
        }
        isPolling = false
    }

    private func pollOnce() async {
        guard MoviePilotSettingsStore.notificationsEnabled() else { return }

        do {
            let messages = try await MoviePilotAPIClient.shared.fetchMessages(page: 1, count: 50)
            lastErrorMessage = nil
            await process(messages: messages)
        } catch {
            lastErrorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    private func process(messages: [MoviePilotMessage]) async {
        guard let maxMessageId = messages.map(\.id).max() else { return }

        guard let lastMessageId = MoviePilotSettingsStore.lastMessageId() else {
            MoviePilotSettingsStore.setLastMessageId(maxMessageId)
            return
        }

        let newMessages = messages
            .filter { $0.id > lastMessageId }
            .sorted { $0.id < $1.id }

        for message in newMessages where shouldNotify(message) {
            await postNotification(for: message)
        }

        if maxMessageId > lastMessageId {
            MoviePilotSettingsStore.setLastMessageId(maxMessageId)
        }
    }

    private func shouldNotify(_ message: MoviePilotMessage) -> Bool {
        guard message.action == 1,
              let category = MoviePilotNotificationCategory.category(for: message) else {
            return false
        }
        return MoviePilotSettingsStore.notificationCategories().contains(category)
    }

    private func postNotification(for message: MoviePilotMessage) async {
        let content = UNMutableNotificationContent()
        content.title = nonEmpty(message.title) ?? L10n.string("媒体助手")
        content.body = nonEmpty(message.text) ?? L10n.string("媒体助手有新的消息")
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "moviepilot.message.\(message.id)",
            content: content,
            trigger: nil
        )

        do {
            try await UNUserNotificationCenter.current().add(request)
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    private func nonEmpty(_ value: String?) -> String? {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed?.isEmpty == false ? trimmed : nil
    }
}

#if os(iOS)
extension MoviePilotNotificationService {
    func scheduleBackgroundRefreshIfNeeded() {
        guard MoviePilotSettingsStore.notificationsEnabled() else { return }

        let request = BGAppRefreshTaskRequest(identifier: Self.backgroundRefreshTaskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)

        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    func performBackgroundRefresh() async {
        await refreshAuthorizationStatus()
        guard MoviePilotSettingsStore.notificationsEnabled(),
              authorizationStatus == .authorized || authorizationStatus == .provisional else {
            return
        }

        await pollOnce()
        scheduleBackgroundRefreshIfNeeded()
    }
}
#endif
