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

    private var feedbackGeneration = 0
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

    func subscribe(
        target: MoviePilotMediaTarget,
        seasons: [Int]? = nil,
        preferences: MoviePilotSubscriptionPreferences = .default
    ) async {
        guard isConfigured else {
            errorMessage = L10n.string("请先配置 MoviePilot")
            return
        }
        guard target.tmdbId != nil else {
            errorMessage = L10n.string("这个条目缺少 TMDB ID，无法添加 MoviePilot 订阅")
            return
        }
        guard !isSubscribing else { return }

        let selectedSeasons = seasons?.sorted()
        if target.kind == .tv, selectedSeasons?.isEmpty != false {
            errorMessage = L10n.string("请选择至少一个季度")
            return
        }

        isSubscribing = true
        clearFeedback()
        defer { isSubscribing = false }

        do {
            if target.kind == .tv, let selectedSeasons {
                var results: [String] = []
                for season in selectedSeasons {
                    let result = try await MoviePilotAPIClient.shared.addSubscribe(
                        target: target,
                        season: season,
                        preferences: preferences
                    )
                    results.append(result)
                }
                showMessage(L10n.string("已提交 %d 个季度订阅", results.count))
            } else {
                showMessage(
                    try await MoviePilotAPIClient.shared.addSubscribe(
                        target: target,
                        preferences: preferences
                    )
                )
            }
            await MoviePilotMediaStatusProvider.shared.invalidate(target)
            await loadStatus(for: target)
        } catch {
            errorMessage = message(for: error)
        }
    }

    func isSeasonSubscribed(_ season: Int) -> Bool {
        status.isSeasonSubscribed(season)
    }

    func isFullySubscribed(target: MoviePilotMediaTarget, seasons: [SeasonDTO] = []) -> Bool {
        guard status.hasSubscription else { return false }
        guard target.kind == .tv else { return true }
        if status.subscriptions.contains(where: { $0.season == nil }) {
            return true
        }

        let regularSeasons = seasons.filter { $0.number > 0 }
        guard !regularSeasons.isEmpty else { return true }
        return regularSeasons.allSatisfy { isSeasonSubscribed($0.number) }
    }

    func shouldOfferWatchlistSubscription(
        target: MoviePilotMediaTarget,
        seasons: [SeasonDTO] = []
    ) -> Bool {
        guard isConfigured, target.tmdbId != nil else { return false }
        if target.kind == .movie, status.hasLibraryItem {
            return false
        }
        return !isFullySubscribed(target: target, seasons: seasons)
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
            try await MoviePilotAPIClient.shared.deleteSubscription(subscription)
        }
    }

    func setDownload(_ download: MoviePilotDownloadTask, paused: Bool, target: MoviePilotMediaTarget) async {
        guard let hash = download.hash, !hash.isEmpty else {
            errorMessage = L10n.string("这个下载任务缺少 hash，无法操作")
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

    func deleteDownload(_ download: MoviePilotDownloadTask, target: MoviePilotMediaTarget) async {
        guard let hash = download.hash, !hash.isEmpty else {
            errorMessage = L10n.string("这个下载任务缺少 hash，无法删除")
            return
        }
        await performAction(refreshing: target) {
            try await MoviePilotAPIClient.shared.deleteDownload(
                hash: hash,
                downloader: download.downloader
            )
        }
    }

    var libraryLabel: String {
        if isLoadingStatus { return L10n.string("检查中...") }
        if status.hasLibraryItem {
            if let detail = libraryDetailLabel {
                return detail
            }
            return L10n.string("已入库")
        }
        return L10n.string("未入库")
    }

    var subscriptionLabel: String {
        if isLoadingStatus { return L10n.string("检查中...") }
        guard status.hasSubscription else { return L10n.string("未订阅") }

        let seasons = status.subscriptions.compactMap(\.season).sorted()
        if !seasons.isEmpty {
            let seasonText = seasons.map { "S\($0)" }.joined(separator: ", ")
            return L10n.string("已订阅 %@", seasonText)
        }
        return L10n.string("已订阅")
    }

    var downloadLabel: String {
        if isLoadingStatus { return L10n.string("检查中...") }
        guard !status.downloads.isEmpty else { return L10n.string("无任务") }
        let active = status.activeDownloadCount
        if active > 0 {
            return L10n.string("%d 个下载中", active)
        }
        return L10n.string("%d 个任务", status.downloads.count)
    }

    private var libraryDetailLabel: String? {
        let seasonPairs = status.libraryItems
            .flatMap { $0.servers.values }
            .compactMap(\.seasons)
            .flatMap { $0 }

        guard !seasonPairs.isEmpty else { return nil }
        let existingEpisodes = seasonPairs.reduce(0) { $0 + $1.value.existingEpisodes.count }
        guard existingEpisodes > 0 else { return nil }
        return L10n.string("已入库 %d 集", existingEpisodes)
    }

    private func message(for error: Error) -> String {
        (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
    }

    private func performAction(refreshing target: MoviePilotMediaTarget, action: () async throws -> String) async {
        guard isConfigured else {
            errorMessage = L10n.string("请先配置 MoviePilot")
            return
        }
        guard !isPerformingAction else { return }

        isPerformingAction = true
        clearFeedback()
        defer { isPerformingAction = false }

        do {
            showMessage(try await action())
            await loadStatus(for: target)
        } catch {
            errorMessage = message(for: error)
        }
    }

    private func clearFeedback() {
        feedbackGeneration += 1
        message = nil
        errorMessage = nil
    }

    private func showMessage(_ value: String) {
        feedbackGeneration += 1
        let generation = feedbackGeneration
        message = value

        Task { [weak self] in
            try? await Task.sleep(nanoseconds: 4_000_000_000)
            await MainActor.run {
                guard let self, self.feedbackGeneration == generation else { return }
                self.message = nil
            }
        }
    }
}
