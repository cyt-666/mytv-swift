import Foundation

enum MoviePilotError: Error, LocalizedError, Sendable {
    case missingConfiguration
    case invalidHost(String)
    case invalidResponse
    case httpError(statusCode: Int, message: String?)
    case decodingError(String)
    case toolFailed(String)
    case searchResultsExpired
    case operationTimedOut(String)

    var errorDescription: String? {
        switch self {
        case .missingConfiguration:
            return L10n.string("请先配置 MoviePilot 地址和 API Key")
        case .invalidHost(let host):
            return L10n.string("MoviePilot 地址无效: %@", host)
        case .invalidResponse:
            return L10n.string("MoviePilot 返回了无效响应")
        case .httpError(let statusCode, let message):
            if let message, !message.isEmpty {
                return L10n.string("MoviePilot 返回错误 %d: %@", statusCode, message)
            }
            return L10n.string("MoviePilot 返回错误 %d", statusCode)
        case .decodingError(let message):
            return L10n.string("解析 MoviePilot 数据失败: %@", message)
        case .toolFailed(let message):
            return message
        case .searchResultsExpired:
            return "搜索结果已过期，请重新搜索后再添加下载"
        case .operationTimedOut(let operation):
            return "\(operation)等待超时，MoviePilot 可能仍在处理"
        }
    }
}

actor MoviePilotAPIClient {
    static let shared = MoviePilotAPIClient()

    private let session: URLSession
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()
    private var toolCatalogCache: ToolCatalogCache?

    private struct ToolCatalogCache {
        let host: String
        let apiKey: String
        let tools: Set<String>
    }

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 360
        self.session = URLSession(configuration: config)
    }

    func validateConnection(host: String, apiKey: String) async throws -> MoviePilotConnectionResult {
        let tools: [MoviePilotTool] = try await request(
            host: host,
            apiKey: apiKey,
            method: "GET",
            path: "/mcp/tools"
        )
        let availableTools = Set(tools.map(\.name))
        toolCatalogCache = ToolCatalogCache(host: host, apiKey: apiKey, tools: availableTools)
        return MoviePilotConnectionResult(
            isConnected: true,
            availableTools: availableTools
        )
    }

    func availableTools(forceRefresh: Bool = false) async throws -> Set<String> {
        guard let config = try await MainActor.run(body: {
            try MoviePilotSettingsStore.currentConfiguration()
        }) else {
            throw MoviePilotError.missingConfiguration
        }

        if !forceRefresh,
           let cache = toolCatalogCache,
           cache.host == config.host,
           cache.apiKey == config.apiKey {
            return cache.tools
        }

        let tools: [MoviePilotTool] = try await request(
            host: config.host,
            apiKey: config.apiKey,
            method: "GET",
            path: "/mcp/tools"
        )
        let names = Set(tools.map(\.name))
        toolCatalogCache = ToolCatalogCache(
            host: config.host,
            apiKey: config.apiKey,
            tools: names
        )
        return names
    }

    func supports(_ feature: MoviePilotFeature) async throws -> Bool {
        let tools = try await availableTools()
        return feature.requiredTools.isSubset(of: tools)
    }

    func hasTool(_ name: String) async throws -> Bool {
        try await availableTools().contains(name)
    }

    func invalidateToolCatalog() {
        toolCatalogCache = nil
    }

    func addSubscribe(
        target: MoviePilotMediaTarget,
        season: Int? = nil,
        preferences: MoviePilotSubscriptionPreferences = .default
    ) async throws -> String {
        var arguments: [String: MoviePilotJSONValue] = [
            "title": .string(target.title),
            "year": .string(target.yearString),
            "media_type": .string(target.kind.rawValue)
        ]
        if let tmdbId = target.tmdbId {
            arguments["tmdb_id"] = .int(tmdbId)
        }
        if let season {
            arguments["season"] = .int(season)
        }
        if let quality = preferences.resolvedQuality {
            arguments["quality"] = .string(quality)
        }
        if let resolution = preferences.resolvedResolution {
            arguments["resolution"] = .string(resolution)
        }
        if let effect = preferences.resolvedEffect {
            arguments["effect"] = .string(effect)
        }
        if let filterGroups = preferences.resolvedFilterGroupNames {
            arguments["filter_groups"] = .stringArray(filterGroups)
        }
        if let sites = preferences.resolvedSiteIDs {
            arguments["sites"] = .intArray(sites)
        }
        return try await callTool("add_subscribe", arguments: arguments)
    }

    func fetchConfiguredSites() async throws -> [MoviePilotConfiguredSite] {
        guard try await hasTool("query_sites") else { return [] }
        let text = try await callTool(
            "query_sites",
            arguments: ["status": .string("active")]
        )
        if text.hasPrefix("未找到") {
            return []
        }
        return try MoviePilotToolTextDecoder.decode(
            [MoviePilotConfiguredSite].self,
            from: text
        )
    }

    func fetchRuleGroups() async throws -> [MoviePilotRuleGroup] {
        guard try await hasTool("query_rule_groups") else { return [] }
        let text = try await callTool(
            "query_rule_groups",
            arguments: ["include_usage": .bool(false)]
        )
        let response = try MoviePilotToolTextDecoder.decode(
            MoviePilotRuleGroupResponse.self,
            from: text
        )
        guard response.success else {
            throw MoviePilotError.toolFailed(response.message ?? "查询 MoviePilot 规则组失败")
        }
        return response.ruleGroups
    }

    func fetchSubscriptions(
        status: String = "all",
        mediaType: String = "all",
        tmdbId: Int? = nil,
        page: Int? = nil
    ) async throws -> [MoviePilotSubscription] {
        if let page {
            return try await fetchSubscriptionsPage(
                status: status,
                mediaType: mediaType,
                tmdbId: tmdbId,
                page: page
            )
        }

        var allSubscriptions: [MoviePilotSubscription] = []
        var currentPage = 1
        while currentPage <= 10 {
            let pageItems = try await fetchSubscriptionsPage(
                status: status,
                mediaType: mediaType,
                tmdbId: tmdbId,
                page: currentPage
            )
            allSubscriptions.append(contentsOf: pageItems)

            guard pageItems.count >= 100 else { break }
            currentPage += 1
        }
        return allSubscriptions
    }

    func fetchDownloadTasks(
        status: String = "all",
        downloader: String? = nil,
        hash: String? = nil,
        title: String? = nil,
        tag: String? = nil
    ) async throws -> [MoviePilotDownloadTask] {
        if status == "downloading", hash == nil, title == nil, tag == nil {
            var queryItems: [URLQueryItem] = []
            if let downloader, !downloader.isEmpty {
                queryItems.append(URLQueryItem(name: "name", value: downloader))
            }
            return try await request(
                method: "GET",
                path: "/download/",
                queryItems: queryItems
            )
        }

        var arguments: [String: MoviePilotJSONValue] = [
            "status": .string(status)
        ]
        if let downloader, !downloader.isEmpty {
            arguments["downloader"] = .string(downloader)
        }
        if let hash, !hash.isEmpty {
            arguments["hash"] = .string(hash)
        }
        if let title, !title.isEmpty {
            arguments["title"] = .string(title)
        }
        if let tag, !tag.isEmpty {
            arguments["tag"] = .string(tag)
        }

        let text = try await callTool("query_download_tasks", arguments: arguments)
        return try decodeArray(MoviePilotDownloadTask.self, fromToolText: text)
    }

    func updateSubscription(id: Int, state: String) async throws -> String {
        let response: MoviePilotRESTResponse = try await request(
            method: "PUT",
            path: "/subscribe/status/\(id)",
            queryItems: [
                URLQueryItem(name: "state", value: state)
            ]
        )
        guard response.success else {
            throw MoviePilotError.toolFailed(response.message ?? L10n.string("更新订阅状态失败"))
        }
        return state == "S" ? L10n.string("已暂停订阅") : L10n.string("已恢复订阅")
    }

    func deleteSubscription(_ subscription: MoviePilotSubscription) async throws -> String {
        guard let mediaIdentifier = subscription.restMediaIdentifier else {
            return try await callTool(
                "delete_subscribe",
                arguments: [
                    "subscribe_id": .int(subscription.id)
                ]
            )
        }

        var queryItems: [URLQueryItem] = []
        if let season = subscription.season {
            queryItems.append(URLQueryItem(name: "season", value: String(season)))
        }
        let response: MoviePilotRESTResponse = try await request(
            method: "DELETE",
            path: "/subscribe/media/\(mediaIdentifier)",
            queryItems: queryItems
        )
        guard response.success else {
            throw MoviePilotError.toolFailed(response.message ?? L10n.string("删除订阅失败"))
        }
        return response.message ?? L10n.string("已删除订阅")
    }

    func modifyDownload(hash: String, downloader: String? = nil, action: String) async throws -> String {
        let normalizedAction = action == "start" ? "start" : "stop"
        _ = try await downloadAction(
            method: "GET",
            path: "/download/\(normalizedAction)/\(hash)",
            downloader: downloader
        )
        return normalizedAction == "start" ? L10n.string("已恢复下载任务") : L10n.string("已暂停下载任务")
    }

    func deleteDownload(hash: String, downloader: String? = nil) async throws -> String {
        _ = try await downloadAction(
            method: "DELETE",
            path: "/download/\(hash)",
            downloader: downloader
        )
        return L10n.string("已删除下载任务")
    }

    private func downloadAction(method: String, path: String, downloader: String?) async throws -> MoviePilotRESTResponse {
        var queryItems: [URLQueryItem] = []
        if let downloader, !downloader.isEmpty {
            queryItems.append(URLQueryItem(name: "name", value: downloader))
        }

        let response: MoviePilotRESTResponse = try await request(
            method: method,
            path: path,
            queryItems: queryItems
        )
        guard response.success else {
            throw MoviePilotError.toolFailed(response.message ?? L10n.string("MoviePilot 操作失败"))
        }
        return response
    }

    private static func mediaKind(for mediaType: String) -> MoviePilotMediaKind? {
        switch mediaType.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "movie", "电影":
            return .movie
        case "tv", "show", "电视剧":
            return .tv
        default:
            return nil
        }
    }

    func fetchStatus(for target: MoviePilotMediaTarget) async throws -> MoviePilotMediaStatus {
        guard target.tmdbId != nil else {
            throw MoviePilotError.toolFailed(L10n.string("这个条目缺少 TMDB ID，无法匹配 MoviePilot 状态"))
        }

        async let subscriptions = querySubscribes(for: target)
        async let libraryItems = queryLibraryExists(for: target)
        async let downloads = queryDownloadTasks(for: target)

        return try await MoviePilotMediaStatus(
            subscriptions: subscriptions,
            libraryItems: libraryItems,
            downloads: downloads
        )
    }

    func fetchMessages(page: Int = 1, count: Int = 50) async throws -> [MoviePilotMessage] {
        try await request(
            method: "GET",
            path: "/message/web",
            queryItems: [
                URLQueryItem(name: "page", value: String(page)),
                URLQueryItem(name: "count", value: String(count))
            ]
        )
    }

    func searchTorrents(
        for target: MoviePilotMediaTarget,
        sites: [Int] = []
    ) async throws -> MoviePilotTorrentSearchSummary {
        guard let tmdbId = target.tmdbId else {
            throw MoviePilotError.toolFailed("这个条目缺少 TMDB ID，无法搜索 MoviePilot 资源")
        }
        let availableTools = try await availableTools(forceRefresh: true)
        let missingTools = MoviePilotFeature.resourceSearch.requiredTools
            .subtracting(availableTools)
            .sorted()
        guard missingTools.isEmpty else {
            throw MoviePilotError.toolFailed(
                "当前 MoviePilot 缺少资源搜索工具：\(missingTools.joined(separator: "、"))"
            )
        }

        var arguments: [String: MoviePilotJSONValue] = [
            "tmdb_id": .int(tmdbId),
            "media_type": .string(target.kind.rawValue)
        ]
        if !sites.isEmpty {
            arguments["sites"] = .intArray(sites)
        }

        let text = try await callTool(
            "search_torrents",
            arguments: arguments,
            timeout: 120
        )
        return try MoviePilotToolTextDecoder.decode(
            MoviePilotTorrentSearchSummary.self,
            from: text
        )
    }

    func fetchSearchResults(
        filters: MoviePilotSearchFilters = MoviePilotSearchFilters(),
        page: Int = 1
    ) async throws -> MoviePilotTorrentSearchPage {
        var arguments: [String: MoviePilotJSONValue] = [
            "page": .int(max(page, 1))
        ]

        func add(_ values: Set<String>, key: String) {
            if !values.isEmpty {
                arguments[key] = .stringArray(values.sorted())
            }
        }

        add(filters.sites, key: "site")
        add(filters.seasons, key: "season")
        add(filters.freeStates, key: "free_state")
        add(filters.videoCodes, key: "video_code")
        add(filters.editions, key: "edition")
        add(filters.resolutions, key: "resolution")
        add(filters.releaseGroups, key: "release_group")

        let pattern = filters.titlePattern.trimmingCharacters(in: .whitespacesAndNewlines)
        if !pattern.isEmpty {
            arguments["title_pattern"] = .string(NSRegularExpression.escapedPattern(for: pattern))
        }

        let text = try await callTool(
            "get_search_results",
            arguments: arguments,
            timeout: 60
        )
        if text.contains("请先使用 search_torrents") || text.contains("没有可用的搜索结果") {
            throw MoviePilotError.searchResultsExpired
        }
        if text.contains("没有符合筛选条件") || text.contains("页没有数据") {
            return .empty(page: page)
        }
        return try MoviePilotToolTextDecoder.decode(
            MoviePilotTorrentSearchPage.self,
            from: text
        )
    }

    func addDownloadTask(torrentReference: String) async throws -> String {
        let reference = torrentReference.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !reference.isEmpty else {
            throw MoviePilotError.toolFailed("这个资源缺少下载引用")
        }

        let text = try await callTool(
            "add_download_tasks",
            arguments: ["torrent_url": .stringArray([reference])],
            timeout: 120
        )
        if text.contains("引用无效") || text.contains("重新使用 get_search_results") {
            throw MoviePilotError.searchResultsExpired
        }
        guard text.contains("任务添加成功") else {
            throw MoviePilotError.toolFailed(text.isEmpty ? "添加下载任务失败" : text)
        }
        return text
    }

    func fetchWorkflows(
        state: String = "all",
        name: String? = nil,
        triggerType: String = "all"
    ) async throws -> [MoviePilotWorkflow] {
        guard try await supports(.workflows) else {
            throw MoviePilotError.toolFailed("当前 MoviePilot 不支持工作流管理")
        }

        var arguments: [String: MoviePilotJSONValue] = [
            "state": .string(state),
            "trigger_type": .string(triggerType)
        ]
        if let name {
            let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmedName.isEmpty {
                arguments["name"] = .string(trimmedName)
            }
        }

        let text = try await callTool("query_workflows", arguments: arguments)
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("未找到相关工作流") {
            return []
        }
        if !trimmed.hasPrefix("["),
           trimmed.contains("查询工作流"),
           trimmed.contains("错误") {
            throw MoviePilotError.toolFailed(trimmed)
        }
        return try MoviePilotToolTextDecoder.decode(
            [MoviePilotWorkflow].self,
            from: trimmed
        )
    }

    func runWorkflow(id: Int, fromBeginning: Bool) async throws -> String {
        guard try await supports(.workflows) else {
            throw MoviePilotError.toolFailed("当前 MoviePilot 不支持工作流管理")
        }
        let text = try await callTool(
            "run_workflow",
            arguments: [
                "workflow_id": .int(id),
                "from_begin": .bool(fromBeginning)
            ],
            timeout: 300
        )
        return try MoviePilotWorkflowResultParser.successMessage(from: text)
    }

    private func querySubscribes(for target: MoviePilotMediaTarget) async throws -> [MoviePilotSubscription] {
        try await fetchSubscriptions(
            status: "all",
            mediaType: target.kind.rawValue,
            tmdbId: target.tmdbId,
            page: 1
        )
    }

    private func queryLibraryExists(for target: MoviePilotMediaTarget) async throws -> [MoviePilotLibraryLookupItem] {
        var arguments: [String: MoviePilotJSONValue] = [
            "media_type": .string(target.kind.rawValue)
        ]
        if let tmdbId = target.tmdbId {
            arguments["tmdb_id"] = .int(tmdbId)
        }

        let text = try await callTool("query_library_exists", arguments: arguments)
        return try decodeArray(MoviePilotLibraryLookupItem.self, fromToolText: text)
    }

    private func queryDownloadTasks(for target: MoviePilotMediaTarget) async throws -> [MoviePilotDownloadTask] {
        let downloads = try await fetchDownloadTasks(status: "all", title: target.title)
        guard let tmdbId = target.tmdbId else { return downloads }

        let matchedByMedia = downloads.filter { $0.media?.tmdbid == tmdbId }
        if !matchedByMedia.isEmpty {
            return matchedByMedia
        }
        return downloads.filter { task in
            let haystack = [task.title, task.name, task.media?.title].compactMap { $0?.lowercased() }
            return haystack.contains { $0.contains(target.title.lowercased()) }
        }
    }

    private func fetchSubscriptionsPage(
        status: String,
        mediaType: String,
        tmdbId: Int?,
        page: Int
    ) async throws -> [MoviePilotSubscription] {
        var arguments: [String: MoviePilotJSONValue] = [
            "status": .string(status),
            "media_type": .string(mediaType),
            "page": .int(page)
        ]
        if let tmdbId {
            arguments["tmdb_id"] = .int(tmdbId)
        }

        let text = try await callTool("query_subscribes", arguments: arguments)
        return try decodeArray(MoviePilotSubscription.self, fromToolText: text)
    }

    private func callTool(
        _ toolName: String,
        arguments: [String: MoviePilotJSONValue],
        timeout: TimeInterval? = nil
    ) async throws -> String {
        let body = MoviePilotToolCallRequest(toolName: toolName, arguments: arguments)
        let response: MoviePilotToolCallResponse
        do {
            response = try await request(
                method: "POST",
                path: "/mcp/tools/call",
                body: encoder.encode(body),
                timeout: timeout
            )
        } catch let error as URLError where error.code == .timedOut {
            throw MoviePilotError.operationTimedOut(toolName)
        }
        guard response.success else {
            throw MoviePilotError.toolFailed(response.error ?? L10n.string("调用 MoviePilot 工具失败"))
        }
        return response.result ?? ""
    }

    private func request<T: Decodable>(
        method: String,
        path: String,
        queryItems: [URLQueryItem] = [],
        body: Data? = nil,
        timeout: TimeInterval? = nil
    ) async throws -> T {
        guard let config = try await MainActor.run(body: {
            try MoviePilotSettingsStore.currentConfiguration()
        }) else {
            throw MoviePilotError.missingConfiguration
        }

        return try await request(
            host: config.host,
            apiKey: config.apiKey,
            method: method,
            path: path,
            queryItems: queryItems,
            body: body,
            timeout: timeout
        )
    }

    private func request<T: Decodable>(
        host: String,
        apiKey: String,
        method: String,
        path: String,
        queryItems: [URLQueryItem] = [],
        body: Data? = nil,
        timeout: TimeInterval? = nil
    ) async throws -> T {
        let url = try makeURL(host: host, path: path, queryItems: queryItems)

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "X-API-KEY")
        request.setValue(AppConstants.userAgent, forHTTPHeaderField: "User-Agent")

        request.httpBody = body
        if let timeout {
            request.timeoutInterval = timeout
        }

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw MoviePilotError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let message = String(data: data, encoding: .utf8)
            throw MoviePilotError.httpError(statusCode: httpResponse.statusCode, message: message)
        }

        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw MoviePilotError.decodingError(error.localizedDescription)
        }
    }

    private func makeURL(host: String, path: String, queryItems: [URLQueryItem]) throws -> URL {
        let trimmedHost = host.trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard !trimmedHost.isEmpty else {
            throw MoviePilotError.invalidHost(host)
        }

        let hostWithScheme: String
        if trimmedHost.contains("://") {
            hostWithScheme = trimmedHost
        } else {
            hostWithScheme = "http://\(trimmedHost)"
        }

        let normalizedPath = path.hasPrefix("/api/v1") ? path : "/api/v1\(path.hasPrefix("/") ? path : "/\(path)")"
        guard var components = URLComponents(string: hostWithScheme + normalizedPath) else {
            throw MoviePilotError.invalidHost(host)
        }
        if !queryItems.isEmpty {
            components.queryItems = queryItems
        }
        guard let url = components.url else {
            throw MoviePilotError.invalidHost(host)
        }
        return url
    }

    private func decodeArray<T: Decodable>(_ type: T.Type, fromToolText text: String) throws -> [T] {
        try MoviePilotToolTextDecoder.decodeArray(type, from: text)
    }
}
