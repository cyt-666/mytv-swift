import Foundation

enum MoviePilotError: Error, LocalizedError, Sendable {
    case missingConfiguration
    case invalidHost(String)
    case invalidResponse
    case httpError(statusCode: Int, message: String?)
    case decodingError(String)
    case toolFailed(String)

    var errorDescription: String? {
        switch self {
        case .missingConfiguration:
            return "请先配置 MoviePilot 地址和 API Key"
        case .invalidHost(let host):
            return "MoviePilot 地址无效: \(host)"
        case .invalidResponse:
            return "MoviePilot 返回了无效响应"
        case .httpError(let statusCode, let message):
            if let message, !message.isEmpty {
                return "MoviePilot 返回错误 \(statusCode): \(message)"
            }
            return "MoviePilot 返回错误 \(statusCode)"
        case .decodingError(let message):
            return "解析 MoviePilot 数据失败: \(message)"
        case .toolFailed(let message):
            return message
        }
    }
}

actor MoviePilotAPIClient {
    static let shared = MoviePilotAPIClient()

    private let session: URLSession
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 30
        self.session = URLSession(configuration: config)
    }

    func validateConnection(host: String, apiKey: String) async throws -> MoviePilotConnectionResult {
        let tools: [MoviePilotTool] = try await request(
            host: host,
            apiKey: apiKey,
            method: "GET",
            path: "/mcp/tools"
        )
        return MoviePilotConnectionResult(
            isConnected: true,
            availableTools: Set(tools.map(\.name))
        )
    }

    func addSubscribe(target: MoviePilotMediaTarget, season: Int? = nil) async throws -> String {
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
        return try await callTool("add_subscribe", arguments: arguments)
    }

    func fetchSubscriptions(
        status: String = "all",
        mediaType: String = "all",
        tmdbId: Int? = nil,
        page: Int? = nil
    ) async throws -> [MoviePilotSubscription] {
        if let page {
            return try await fetchSubscriptionsPage(status: status, mediaType: mediaType, tmdbId: tmdbId, page: page)
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
        try await callTool(
            "update_subscribe",
            arguments: [
                "subscribe_id": .int(id),
                "state": .string(state)
            ]
        )
    }

    func deleteSubscription(id: Int) async throws -> String {
        try await callTool(
            "delete_subscribe",
            arguments: [
                "subscribe_id": .int(id)
            ]
        )
    }

    func modifyDownload(hash: String, downloader: String? = nil, action: String) async throws -> String {
        var arguments: [String: MoviePilotJSONValue] = [
            "hash": .string(hash),
            "action": .string(action)
        ]
        if let downloader, !downloader.isEmpty {
            arguments["downloader"] = .string(downloader)
        }
        return try await callTool("modify_download", arguments: arguments)
    }

    func deleteDownload(hash: String, downloader: String? = nil, deleteFiles: Bool = false) async throws -> String {
        var arguments: [String: MoviePilotJSONValue] = [
            "hash": .string(hash),
            "delete_files": .bool(deleteFiles)
        ]
        if let downloader, !downloader.isEmpty {
            arguments["downloader"] = .string(downloader)
        }
        return try await callTool("delete_download", arguments: arguments)
    }

    func fetchStatus(for target: MoviePilotMediaTarget) async throws -> MoviePilotMediaStatus {
        guard target.tmdbId != nil else {
            throw MoviePilotError.toolFailed("这个条目缺少 TMDB ID，无法匹配 MoviePilot 状态")
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

    private func callTool(_ toolName: String, arguments: [String: MoviePilotJSONValue]) async throws -> String {
        let body = MoviePilotToolCallRequest(toolName: toolName, arguments: arguments)
        let response: MoviePilotToolCallResponse = try await request(
            method: "POST",
            path: "/mcp/tools/call",
            body: encoder.encode(body)
        )
        guard response.success else {
            throw MoviePilotError.toolFailed(response.error ?? "调用 MoviePilot 工具失败")
        }
        return response.result ?? ""
    }

    private func request<T: Decodable>(
        method: String,
        path: String,
        queryItems: [URLQueryItem] = [],
        body: Data? = nil
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
            body: body
        )
    }

    private func request<T: Decodable>(
        host: String,
        apiKey: String,
        method: String,
        path: String,
        queryItems: [URLQueryItem] = [],
        body: Data? = nil
    ) async throws -> T {
        let url = try makeURL(host: host, path: path, queryItems: queryItems)

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "X-API-KEY")
        request.setValue(AppConstants.userAgent, forHTTPHeaderField: "User-Agent")

        request.httpBody = body

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
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if let decoded = tryDecodeArray(type, from: trimmed) {
            return decoded
        }

        let startIndices = text.indices.filter { text[$0] == "[" }
        let endIndices = text.indices.filter { text[$0] == "]" }.reversed()
        var lastDecodingError: Error?

        for start in startIndices {
            for end in endIndices where start <= end {
                let candidate = String(text[start...end])
                do {
                    return try decoder.decode([T].self, from: Data(candidate.utf8))
                } catch {
                    lastDecodingError = error
                }
            }
        }

        if let lastDecodingError {
            throw MoviePilotError.decodingError(lastDecodingError.localizedDescription)
        }

        return []
    }

    private func tryDecodeArray<T: Decodable>(_ type: T.Type, from json: String) -> [T]? {
        guard !json.isEmpty else {
            return []
        }
        guard let data = json.data(using: .utf8) else {
            return nil
        }
        return try? decoder.decode([T].self, from: data)
    }
}
