import Foundation

enum MoviePilotCenterTab: String, CaseIterable, Identifiable {
    case downloads = "下载任务"
    case subscriptions = "订阅"
    case messages = "通知消息"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .downloads: return "arrow.down.circle.fill"
        case .subscriptions: return "checkmark.seal.fill"
        case .messages: return "bell.badge.fill"
        }
    }

    var segmentTitle: String {
        switch self {
        case .downloads: return L10n.string("下载")
        case .subscriptions: return L10n.string("订阅")
        case .messages: return L10n.string("消息")
        }
    }
}

struct MoviePilotSubscriptionResolution {
    let posterURL: String?
    let route: Route?

    static let unresolved = MoviePilotSubscriptionResolution(posterURL: nil, route: nil)
}

struct MoviePilotMessageResolution {
    let posterURL: String?
    let route: Route?

    static let unresolved = MoviePilotMessageResolution(posterURL: nil, route: nil)
}

@Observable
@MainActor
final class MoviePilotCenterViewModel {
    var subscriptions: [MoviePilotSubscription] = []
    var downloads: [MoviePilotDownloadTask] = []
    var messages: [MoviePilotMessage] = []
    var subscriptionResolutions: [Int: MoviePilotSubscriptionResolution] = [:]
    var messageResolutions: [Int: MoviePilotMessageResolution] = [:]

    var isLoadingSubscriptions = false
    var isLoadingDownloads = false
    var isLoadingMessages = false
    var isResolvingSubscriptionPosters = false
    var isResolvingMessagePosters = false
    var hasLoadedSubscriptions = false
    var hasLoadedDownloads = false
    var hasLoadedMessages = false
    var isPerformingAction = false
    var actionMessage: String?
    var errorMessage: String?

    private var feedbackGeneration = 0
    private var subscriptionResolutionGeneration = 0
    private var messageResolutionGeneration = 0
    private var messageResolutionCache: [String: MoviePilotMessageResolution] = [:]

    var isConfigured: Bool {
        (try? MoviePilotSettingsStore.currentConfiguration()) != nil
    }

    var isLoading: Bool {
        isLoadingSubscriptions || isLoadingDownloads || isLoadingMessages
    }

    func loadAll() async {
        guard isConfigured else {
            subscriptions = []
            downloads = []
            messages = []
            hasLoadedSubscriptions = false
            hasLoadedDownloads = false
            hasLoadedMessages = false
            errorMessage = L10n.string("请先在设置中配置 MoviePilot")
            return
        }

        async let downloadsLoad: Void = loadDownloads()
        async let subscriptionsLoad: Void = loadSubscriptions()
        async let messagesLoad: Void = loadMessages()
        _ = await (downloadsLoad, subscriptionsLoad, messagesLoad)
    }

    func loadDownloads() async {
        guard isConfigured else {
            downloads = []
            errorMessage = L10n.string("请先在设置中配置 MoviePilot")
            return
        }
        guard !isLoadingDownloads else { return }

        isLoadingDownloads = true
        errorMessage = nil
        defer { isLoadingDownloads = false }

        do {
            downloads = try await MoviePilotAPIClient.shared.fetchDownloadTasks(status: "downloading")
            hasLoadedDownloads = true
        } catch {
            if !hasLoadedDownloads {
                downloads = []
            }
            errorMessage = message(for: error)
        }
    }

    func loadSubscriptions() async {
        guard isConfigured else {
            subscriptions = []
            errorMessage = L10n.string("请先在设置中配置 MoviePilot")
            return
        }
        guard !isLoadingSubscriptions else { return }

        isLoadingSubscriptions = true
        errorMessage = nil
        defer { isLoadingSubscriptions = false }

        do {
            let fetchedSubscriptions = try await MoviePilotAPIClient.shared.fetchSubscriptions(status: "all", mediaType: "all")
            subscriptions = fetchedSubscriptions
            hasLoadedSubscriptions = true

            subscriptionResolutionGeneration += 1
            let generation = subscriptionResolutionGeneration
            Task {
                await self.loadSubscriptionResolutions(for: fetchedSubscriptions, generation: generation)
            }
        } catch {
            if !hasLoadedSubscriptions {
                subscriptions = []
            }
            errorMessage = message(for: error)
        }
    }

    func loadMessages() async {
        guard isConfigured else {
            messages = []
            errorMessage = L10n.string("请先在设置中配置 MoviePilot")
            return
        }
        guard !isLoadingMessages else { return }

        isLoadingMessages = true
        errorMessage = nil
        defer { isLoadingMessages = false }

        do {
            let fetchedMessages = try await MoviePilotAPIClient.shared.fetchMessages(page: 1, count: 50)
                .sorted { $0.id > $1.id }
            messages = fetchedMessages
            hasLoadedMessages = true

            messageResolutionGeneration += 1
            let generation = messageResolutionGeneration
            Task {
                await self.loadMessageResolutions(for: fetchedMessages, generation: generation)
            }
        } catch {
            if !hasLoadedMessages {
                messages = []
            }
            errorMessage = message(for: error)
        }
    }

    func setSubscription(_ subscription: MoviePilotSubscription, paused: Bool) async {
        await performAction(refresh: loadSubscriptions) {
            try await MoviePilotAPIClient.shared.updateSubscription(
                id: subscription.id,
                state: paused ? "S" : "R"
            )
        }
    }

    func deleteSubscription(_ subscription: MoviePilotSubscription) async {
        await performAction(refresh: loadSubscriptions) {
            try await MoviePilotAPIClient.shared.deleteSubscription(subscription)
        }
    }

    func setDownload(_ download: MoviePilotDownloadTask, paused: Bool) async {
        guard let hash = download.hash, !hash.isEmpty else {
            errorMessage = L10n.string("这个下载任务缺少 hash，无法操作")
            return
        }

        await performAction(refresh: loadDownloads) {
            try await MoviePilotAPIClient.shared.modifyDownload(
                hash: hash,
                downloader: download.downloader,
                action: paused ? "stop" : "start"
            )
        }
    }

    func deleteDownload(_ download: MoviePilotDownloadTask) async {
        guard let hash = download.hash, !hash.isEmpty else {
            errorMessage = L10n.string("这个下载任务缺少 hash，无法删除")
            return
        }

        await performAction(refresh: loadDownloads) {
            try await MoviePilotAPIClient.shared.deleteDownload(
                hash: hash,
                downloader: download.downloader
            )
        }
    }

    func refresh(tab: MoviePilotCenterTab) async {
        switch tab {
        case .downloads:
            await loadDownloads()
        case .subscriptions:
            await loadSubscriptions()
        case .messages:
            await loadMessages()
        }
    }

    func visibleSubscriptions(for kind: MoviePilotSubscriptionKind) -> [MoviePilotSubscription] {
        subscriptions.filter { subscription in
            subscription.mediaKind == kind.mediaKind
        }
    }

    func subscriptionPosterURL(for subscription: MoviePilotSubscription) -> String? {
        subscriptionResolutions[subscription.id]?.posterURL
    }

    func subscriptionRoute(for subscription: MoviePilotSubscription) -> Route? {
        subscriptionResolutions[subscription.id]?.route
    }

    func messagePosterURL(for message: MoviePilotMessage) -> String? {
        nonEmpty(message.image) ?? messageResolutions[message.id]?.posterURL
    }

    func messageRoute(for message: MoviePilotMessage) -> Route? {
        messageResolutions[message.id]?.route
    }

    private func performAction(refresh: () async -> Void, action: () async throws -> String) async {
        guard isConfigured else {
            errorMessage = L10n.string("请先在设置中配置 MoviePilot")
            return
        }
        guard !isPerformingAction else { return }

        isPerformingAction = true
        clearFeedback()
        defer { isPerformingAction = false }

        do {
            showActionMessage(try await action())
            await refresh()
        } catch {
            errorMessage = message(for: error)
        }
    }

    private func clearFeedback() {
        feedbackGeneration += 1
        actionMessage = nil
        errorMessage = nil
    }

    private func showActionMessage(_ message: String) {
        feedbackGeneration += 1
        let generation = feedbackGeneration
        actionMessage = message

        Task { [weak self] in
            try? await Task.sleep(nanoseconds: 4_000_000_000)
            await MainActor.run {
                guard let self, self.feedbackGeneration == generation else { return }
                self.actionMessage = nil
            }
        }
    }

    private func message(for error: Error) -> String {
        (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
    }

    private func loadSubscriptionResolutions(
        for subscriptions: [MoviePilotSubscription],
        generation: Int
    ) async {
        guard generation == subscriptionResolutionGeneration else { return }
        isResolvingSubscriptionPosters = true
        defer { isResolvingSubscriptionPosters = false }

        let visibleIds = Set(subscriptions.map(\.id))
        subscriptionResolutions = subscriptionResolutions.filter { visibleIds.contains($0.key) }

        let missingSubscriptions = subscriptions.filter { subscription in
            subscriptionResolutions[subscription.id] == nil &&
            !subscription.displayTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }

        for subscription in missingSubscriptions {
            guard generation == subscriptionResolutionGeneration else { return }
            let resolution = await resolveSubscription(for: subscription)
            guard generation == subscriptionResolutionGeneration else { return }
            subscriptionResolutions[subscription.id] = resolution
        }
    }

    private func resolveSubscription(for subscription: MoviePilotSubscription) async -> MoviePilotSubscriptionResolution {
        do {
            let results = try await SearchAPI.search(query: subscription.displayTitle, limit: 8)
            let preferredKind = subscription.mediaKind
            let preferredYear = subscription.year.flatMap(Int.init)

            let candidates = results.filter { result in
                if preferredKind == .movie {
                    return result.movie != nil
                }
                if preferredKind == .tv {
                    return result.show != nil
                }
                return result.movie != nil || result.show != nil
            }

            let exactYearMatch = candidates.first { result in
                if let preferredYear {
                    return (result.movie?.year ?? result.show?.year) == preferredYear
                }
                return false
            }

            let matched = exactYearMatch ?? candidates.first
            let posterURL = matched?.movie?.images?.poster?.first ?? matched?.show?.images?.poster?.first
            let route: Route?

            if let movie = matched?.movie {
                route = .movieDetail(id: movie.ids.trakt)
            } else if let show = matched?.show {
                route = .showDetail(id: show.ids.trakt)
            } else {
                route = nil
            }

            return MoviePilotSubscriptionResolution(posterURL: posterURL, route: route)
        } catch {
            return .unresolved
        }
    }

    private func loadMessageResolutions(
        for messages: [MoviePilotMessage],
        generation: Int
    ) async {
        guard generation == messageResolutionGeneration else { return }
        isResolvingMessagePosters = true
        defer { isResolvingMessagePosters = false }

        let visibleIds = Set(messages.map(\.id))
        messageResolutions = messageResolutions.filter { visibleIds.contains($0.key) }

        let missingMessages = messages.compactMap { message -> (MoviePilotMessage, MoviePilotMessageMediaHint)? in
            guard messageResolutions[message.id] == nil,
                  nonEmpty(message.image) == nil,
                  let hint = mediaHint(for: message) else {
                return nil
            }
            return (message, hint)
        }

        for (message, hint) in missingMessages {
            guard generation == messageResolutionGeneration else { return }

            if let cachedResolution = messageResolutionCache[hint.cacheKey] {
                messageResolutions[message.id] = cachedResolution
                continue
            }

            let resolution = await resolveMessage(hint: hint)
            guard generation == messageResolutionGeneration else { return }
            messageResolutionCache[hint.cacheKey] = resolution
            messageResolutions[message.id] = resolution
        }
    }

    private func resolveMessage(hint: MoviePilotMessageMediaHint) async -> MoviePilotMessageResolution {
        if let tmdbId = hint.tmdbId {
            do {
                let results = try await SearchAPI.lookupTMDB(id: tmdbId, mediaKind: hint.kind)
                if let resolution = resolution(from: results, preferredKind: hint.kind, preferredYear: hint.year) {
                    return resolution
                }
            } catch {
                // Fall back to title search below.
            }
        }

        guard let title = hint.title else { return .unresolved }

        do {
            let results = try await SearchAPI.search(query: title, limit: 8)
            return resolution(from: results, preferredKind: hint.kind, preferredYear: hint.year) ?? .unresolved
        } catch {
            return .unresolved
        }
    }

    private func resolution(
        from results: [SearchResultDTO],
        preferredKind: MoviePilotMediaKind?,
        preferredYear: Int?
    ) -> MoviePilotMessageResolution? {
        let candidates = results.filter { result in
            if preferredKind == .movie {
                return result.movie != nil
            }
            if preferredKind == .tv {
                return result.show != nil
            }
            return result.movie != nil || result.show != nil
        }

        let exactYearMatch = candidates.first { result in
            if let preferredYear {
                return (result.movie?.year ?? result.show?.year) == preferredYear
            }
            return false
        }

        guard let matched = exactYearMatch ?? candidates.first else { return nil }
        let posterURL = matched.movie?.images?.poster?.first ?? matched.show?.images?.poster?.first
        let route: Route?

        if let movie = matched.movie {
            route = .movieDetail(id: movie.ids.trakt)
        } else if let show = matched.show {
            route = .showDetail(id: show.ids.trakt)
        } else {
            route = nil
        }

        return MoviePilotMessageResolution(posterURL: posterURL, route: route)
    }

    private struct MoviePilotMessageMediaHint {
        let title: String?
        let year: Int?
        let tmdbId: Int?
        let kind: MoviePilotMediaKind?

        var cacheKey: String {
            if let tmdbId {
                return "tmdb:\(kind?.rawValue ?? "all"):\(tmdbId)"
            }

            let normalizedTitle = title?
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased() ?? ""
            return "title:\(kind?.rawValue ?? "all"):\(year.map(String.init) ?? "any"):\(normalizedTitle)"
        }
    }

    private func mediaHint(for message: MoviePilotMessage) -> MoviePilotMessageMediaHint? {
        let values = [message.title, message.text, message.link]
            .compactMap(nonEmpty)
        let haystack = values.joined(separator: "\n")
        let markdownLabels = markdownLinkLabels(in: haystack)
        let title = markdownLabels.first ?? mediaTitlePrefix(from: MoviePilotMessageTextFormatter.cleaned(message.title))
        let year = title.flatMap(extractYear)
        let tmdbReference = tmdbReference(in: haystack)
        let kind = tmdbReference?.kind ?? kind(from: message)

        if title == nil && tmdbReference == nil {
            return nil
        }

        return MoviePilotMessageMediaHint(
            title: title,
            year: year,
            tmdbId: tmdbReference?.id,
            kind: kind
        )
    }

    private func kind(from message: MoviePilotMessage) -> MoviePilotMediaKind? {
        let values = [message.mtype, message.title, message.text]
            .compactMap(nonEmpty)
            .joined(separator: " ")

        if values.contains("剧集") || values.localizedCaseInsensitiveContains("tv/") {
            return .tv
        }
        if values.contains("电影") || values.localizedCaseInsensitiveContains("movie/") {
            return .movie
        }
        return nil
    }

    private func markdownLinkLabels(in value: String) -> [String] {
        matches(
            pattern: #"\[([^\]]+)\]\(([^)]+)\)"#,
            in: value,
            captureIndex: 1
        )
        .compactMap { nonEmpty($0) }
    }

    private func tmdbReference(in value: String) -> (kind: MoviePilotMediaKind, id: Int)? {
        let matches = matches(
            pattern: #"themoviedb\.org/(movie|tv)/([0-9]+)"#,
            in: value,
            captureIndices: [1, 2]
        )

        guard let first = matches.first,
              first.count == 2,
              let id = Int(first[1]) else {
            return nil
        }

        let kind: MoviePilotMediaKind = first[0] == "tv" ? .tv : .movie
        return (kind, id)
    }

    private func mediaTitlePrefix(from value: String?) -> String? {
        guard let value = nonEmpty(value) else { return nil }
        let pattern = #"\((19|20)[0-9]{2}\)"#
        guard let range = value.range(of: pattern, options: .regularExpression) else {
            return nil
        }
        return nonEmpty(String(value[..<range.upperBound]))
    }

    private func extractYear(from value: String) -> Int? {
        guard let range = value.range(of: #"(19|20)[0-9]{2}"#, options: .regularExpression) else {
            return nil
        }
        return Int(value[range])
    }

    private func matches(pattern: String, in value: String, captureIndex: Int) -> [String] {
        matches(pattern: pattern, in: value, captureIndices: [captureIndex]).compactMap(\.first)
    }

    private func matches(pattern: String, in value: String, captureIndices: [Int]) -> [[String]] {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let nsValue = value as NSString
        let range = NSRange(location: 0, length: nsValue.length)

        return regex.matches(in: value, range: range).compactMap { match in
            let captures = captureIndices.compactMap { index -> String? in
                let range = match.range(at: index)
                guard range.location != NSNotFound else { return nil }
                return nsValue.substring(with: range)
            }
            return captures.count == captureIndices.count ? captures : nil
        }
    }

    private func nonEmpty(_ value: String?) -> String? {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed?.isEmpty == false ? trimmed : nil
    }
}
