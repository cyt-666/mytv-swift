import Foundation

@Observable
@MainActor
final class MoviePilotResourceSearchViewModel {
    let target: MoviePilotMediaTarget
    let preferredSeason: Int?
    let preferredEpisode: Int?

    var summary: MoviePilotTorrentSearchSummary?
    var page = MoviePilotTorrentSearchPage.empty()
    var filters = MoviePilotSearchFilters()
    var isSearching = false
    var isLoadingPage = false
    var downloadingReference: String?
    var message: String?
    var errorMessage: String?
    var cachedAt: Date?
    var isUsingCachedResults = false

    private var snapshot: MoviePilotResourceSearchSnapshot?

    init(
        target: MoviePilotMediaTarget,
        preferredSeason: Int? = nil,
        preferredEpisode: Int? = nil
    ) {
        self.target = target
        self.preferredSeason = preferredSeason
        self.preferredEpisode = preferredEpisode
    }

    var sortedResults: [MoviePilotTorrentSearchResult] {
        page.results.sorted { lhs, rhs in
            let left = lhs.matchPriority(
                season: preferredSeason,
                episode: preferredEpisode
            )
            let right = rhs.matchPriority(
                season: preferredSeason,
                episode: preferredEpisode
            )
            if left != right {
                return left < right
            }
            return (lhs.torrentInfo?.seeders ?? 0) > (rhs.torrentInfo?.seeders ?? 0)
        }
    }

    var preferredEpisodeCode: String? {
        guard let preferredSeason else { return nil }
        if let preferredEpisode {
            return String(format: "S%02dE%02d", preferredSeason, preferredEpisode)
        }
        return String(format: "S%02d", preferredSeason)
    }

    var resultSourceText: String? {
        guard let cachedAt else { return nil }
        if isUsingCachedResults {
            let minutes = max(0, Int(Date().timeIntervalSince(cachedAt) / 60))
            return minutes == 0 ? "使用刚刚缓存的结果" : "使用 \(minutes) 分钟前的缓存"
        }
        return "刚刚更新"
    }

    func search(forceRefresh: Bool = false) async {
        guard !isSearching else { return }

        if !forceRefresh,
           let cached = MoviePilotResourceSearchCache.load(for: target) {
            filters = MoviePilotSearchFilters()
            apply(cached, isCached: true)
            return
        }

        isSearching = true
        message = nil
        errorMessage = nil
        defer { isSearching = false }

        do {
            let fetchedSummary = try await MoviePilotAPIClient.shared.searchTorrents(for: target)
            let results = try await fetchAllResults(summary: fetchedSummary)
            let freshSnapshot = MoviePilotResourceSearchSnapshot(
                summary: fetchedSummary,
                results: results,
                cachedAt: .now
            )
            filters = MoviePilotSearchFilters()
            MoviePilotResourceSearchCache.save(freshSnapshot, for: target)
            apply(freshSnapshot, isCached: false)
        } catch {
            if snapshot == nil {
                page = .empty()
            }
            errorMessage = errorText(error)
        }
    }

    func applyFilters() async {
        do {
            try await loadPage(1)
        } catch {
            errorMessage = errorText(error)
        }
    }

    func resetFilters() async {
        filters = MoviePilotSearchFilters()
        await applyFilters()
    }

    func loadPage(_ requestedPage: Int) async throws {
        guard !isLoadingPage else { return }
        guard let snapshot else {
            page = .empty(page: requestedPage)
            return
        }
        isLoadingPage = true
        errorMessage = nil
        defer { isLoadingPage = false }

        page = snapshot.page(filters: filters, requestedPage: requestedPage)
    }

    func download(_ result: MoviePilotTorrentSearchResult) async -> Bool {
        guard let reference = result.torrentInfo?.torrentURL,
              !reference.isEmpty else {
            errorMessage = "这个资源缺少有效的下载引用"
            return false
        }
        guard downloadingReference == nil else { return false }

        downloadingReference = reference
        message = nil
        errorMessage = nil
        defer { downloadingReference = nil }

        do {
            message = try await MoviePilotAPIClient.shared.addDownloadTask(
                torrentReference: reference
            )
            await MoviePilotMediaStatusProvider.shared.invalidate(target)
            return true
        } catch {
            errorMessage = errorText(error)
            return false
        }
    }

    private func errorText(_ error: Error) -> String {
        (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
    }

    private func apply(
        _ snapshot: MoviePilotResourceSearchSnapshot,
        isCached: Bool
    ) {
        self.snapshot = snapshot
        summary = snapshot.summary
        cachedAt = snapshot.cachedAt
        isUsingCachedResults = isCached
        page = snapshot.page(filters: filters, requestedPage: 1)
    }

    private func fetchAllResults(
        summary: MoviePilotTorrentSearchSummary
    ) async throws -> [MoviePilotTorrentSearchResult] {
        if summary.totalCount == 0 ||
            summary.message?.hasPrefix("未找到相关种子资源") == true {
            return []
        }

        let firstPage = try await MoviePilotAPIClient.shared.fetchSearchResults(page: 1)
        guard firstPage.totalPages > 1 else {
            return firstPage.results
        }

        var results = firstPage.results
        for pageNumber in 2...firstPage.totalPages {
            let nextPage = try await MoviePilotAPIClient.shared.fetchSearchResults(
                page: pageNumber
            )
            results.append(contentsOf: nextPage.results)
        }
        return results
    }
}
