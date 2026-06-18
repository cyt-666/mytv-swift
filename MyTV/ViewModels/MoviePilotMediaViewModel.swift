import Foundation

@Observable
@MainActor
final class MoviePilotMediaViewModel {
    var status = MoviePilotMediaStatus.empty
    var isLoadingStatus = false
    var isSubscribing = false
    var isPerformingAction = false
    var message: String?
    var errorMessage: String?

    private var loadedTarget: MoviePilotMediaTarget?

    var isConfigured: Bool {
        (try? MoviePilotSettingsStore.currentConfiguration()) != nil
    }

    func loadStatusIfNeeded(for target: MoviePilotMediaTarget) async {
        guard loadedTarget != target else { return }
        await loadStatus(for: target)
    }

    func loadStatus(for target: MoviePilotMediaTarget) async {
        loadedTarget = target
        guard isConfigured else {
            status = .empty
            errorMessage = nil
            message = nil
            return
        }

        guard !isLoadingStatus else { return }
        isLoadingStatus = true
        errorMessage = nil
        defer { isLoadingStatus = false }

        do {
            status = try await MoviePilotAPIClient.shared.fetchStatus(for: target)
        } catch {
            status = .empty
            errorMessage = message(for: error)
        }
    }

    func subscribe(target: MoviePilotMediaTarget, seasons: [Int]? = nil) async {
        guard isConfigured else {
            errorMessage = "请先配置 MoviePilot"
            return
        }
        guard target.tmdbId != nil else {
            errorMessage = "这个条目缺少 TMDB ID，无法添加 MoviePilot 订阅"
            return
        }
        guard !isSubscribing else { return }

        let selectedSeasons = seasons?.sorted()
        if target.kind == .tv, selectedSeasons?.isEmpty != false {
            errorMessage = "请选择至少一个季度"
            return
        }

        isSubscribing = true
        message = nil
        errorMessage = nil
        defer { isSubscribing = false }

        do {
            if target.kind == .tv, let selectedSeasons {
                var results: [String] = []
                for season in selectedSeasons {
                    let result = try await MoviePilotAPIClient.shared.addSubscribe(target: target, season: season)
                    results.append(result)
                }
                message = "已提交 \(results.count) 个季度订阅"
            } else {
                message = try await MoviePilotAPIClient.shared.addSubscribe(target: target)
            }
            await loadStatus(for: target)
        } catch {
            errorMessage = message(for: error)
        }
    }

    func isSeasonSubscribed(_ season: Int) -> Bool {
        status.isSeasonSubscribed(season)
    }

    func setSubscription(_ subscription: MoviePilotSubscription, paused: Bool, target: MoviePilotMediaTarget) async {
        await performAction(refreshing: target) {
            try await MoviePilotAPIClient.shared.updateSubscription(
                id: subscription.id,
                state: paused ? "S" : "R"
            )
        }
    }

    func deleteSubscription(_ subscription: MoviePilotSubscription, target: MoviePilotMediaTarget) async {
        await performAction(refreshing: target) {
            try await MoviePilotAPIClient.shared.deleteSubscription(id: subscription.id)
        }
    }

    func setDownload(_ download: MoviePilotDownloadTask, paused: Bool, target: MoviePilotMediaTarget) async {
        guard let hash = download.hash, !hash.isEmpty else {
            errorMessage = "这个下载任务缺少 hash，无法操作"
            return
        }
        await performAction(refreshing: target) {
            try await MoviePilotAPIClient.shared.modifyDownload(
                hash: hash,
                downloader: download.downloader,
                action: paused ? "stop" : "start"
            )
        }
    }

    func deleteDownload(_ download: MoviePilotDownloadTask, deleteFiles: Bool, target: MoviePilotMediaTarget) async {
        guard let hash = download.hash, !hash.isEmpty else {
            errorMessage = "这个下载任务缺少 hash，无法删除"
            return
        }
        await performAction(refreshing: target) {
            try await MoviePilotAPIClient.shared.deleteDownload(
                hash: hash,
                downloader: download.downloader,
                deleteFiles: deleteFiles
            )
        }
    }

    var libraryLabel: String {
        if isLoadingStatus { return "检查中..." }
        if status.hasLibraryItem {
            if let detail = libraryDetailLabel {
                return detail
            }
            return "已入库"
        }
        return "未入库"
    }

    var subscriptionLabel: String {
        if isLoadingStatus { return "检查中..." }
        guard status.hasSubscription else { return "未订阅" }

        let seasons = status.subscriptions.compactMap(\.season).sorted()
        if !seasons.isEmpty {
            let seasonText = seasons.map { "S\($0)" }.joined(separator: ", ")
            return "已订阅 \(seasonText)"
        }
        return "已订阅"
    }

    var downloadLabel: String {
        if isLoadingStatus { return "检查中..." }
        guard !status.downloads.isEmpty else { return "无任务" }
        let active = status.activeDownloadCount
        if active > 0 {
            return "\(active) 个下载中"
        }
        return "\(status.downloads.count) 个任务"
    }

    private var libraryDetailLabel: String? {
        let seasonPairs = status.libraryItems
            .flatMap { $0.servers.values }
            .compactMap(\.seasons)
            .flatMap { $0 }

        guard !seasonPairs.isEmpty else { return nil }
        let existingEpisodes = seasonPairs.reduce(0) { $0 + $1.value.existingEpisodes.count }
        guard existingEpisodes > 0 else { return nil }
        return "已入库 \(existingEpisodes) 集"
    }

    private func message(for error: Error) -> String {
        (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
    }

    private func performAction(refreshing target: MoviePilotMediaTarget, action: () async throws -> String) async {
        guard isConfigured else {
            errorMessage = "请先配置 MoviePilot"
            return
        }
        guard !isPerformingAction else { return }

        isPerformingAction = true
        message = nil
        errorMessage = nil
        defer { isPerformingAction = false }

        do {
            message = try await action()
            await loadStatus(for: target)
        } catch {
            errorMessage = message(for: error)
        }
    }
}
