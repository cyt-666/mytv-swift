import Foundation

enum APIError: Error, LocalizedError {
    case invalidURL
    case httpError(statusCode: Int, data: Data?)
    case decodingError(Error)
    case noData
    case unauthorized
    case refreshTokenFailed

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "无效的 URL"
        case .httpError(let code, _): return "HTTP 错误: \(code)"
        case .decodingError(let err): return "数据解码失败: \(err.localizedDescription)"
        case .noData: return "无数据返回"
        case .unauthorized: return "未授权"
        case .refreshTokenFailed: return "刷新 Token 失败"
        }
    }
}

actor TraktAPIClient {
    static let shared = TraktAPIClient()

    private let session: URLSession
    private var authToken: String?

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 30
        config.httpAdditionalHeaders = [
            "Content-Type": "application/json",
            "trakt-api-version": "2",
            "trakt-api-key": AppConstants.clientID,
            "User-Agent": AppConstants.userAgent
        ]
        self.session = URLSession(configuration: config)
    }

    func setAuthToken(_ token: String?) {
        self.authToken = token
    }

    func request<T: Decodable>(
        method: String = "GET",
        uri: String,
        params: [String: String]? = nil,
        body: [String: Any]? = nil,
        requiresAuth: Bool = false
    ) async throws -> T {
        guard var components = URLComponents(string: AppConstants.apiBaseURL + uri) else {
            throw APIError.invalidURL
        }

        if let params, !params.isEmpty {
            let existing = components.queryItems ?? []
            let newItems = params.map { URLQueryItem(name: $0.key, value: $0.value) }
            components.queryItems = existing + newItems
        }

        guard let url = components.url else { throw APIError.invalidURL }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = method

        if let authToken, requiresAuth || method != "GET" {
            urlRequest.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        }

        if let body {
            urlRequest.httpBody = try JSONSerialization.data(withJSONObject: body)
        }

        let (data, response) = try await session.data(for: urlRequest)
        let httpResponse = response as? HTTPURLResponse

        // Handle 401 with token refresh retry
        if httpResponse?.statusCode == 401, requiresAuth {
            do {
                try await AuthService.shared.refreshToken()
                if let newToken = await AuthService.shared.currentToken?.accessToken {
                    self.authToken = newToken
                    urlRequest.setValue("Bearer \(newToken)", forHTTPHeaderField: "Authorization")
                    let (retryData, retryResponse) = try await session.data(for: urlRequest)
                    guard let retryHTTP = retryResponse as? HTTPURLResponse,
                          (200...299).contains(retryHTTP.statusCode) else {
                        throw APIError.httpError(
                            statusCode: (retryResponse as? HTTPURLResponse)?.statusCode ?? 0,
                            data: retryData
                        )
                    }
                    return try JSONDecoder().decode(T.self, from: retryData)
                }
            } catch {
                throw APIError.refreshTokenFailed
            }
        }

        guard let statusCode = httpResponse?.statusCode else {
            throw APIError.noData
        }

        guard (200...299).contains(statusCode) else {
            throw APIError.httpError(statusCode: statusCode, data: data)
        }

        // Handle 204 No Content (e.g., sync operations)
        if statusCode == 204 {
            if T.self == EmptyResponse.self {
                return EmptyResponse() as! T
            }
            throw APIError.noData
        }

        do {
            let decoder = JSONDecoder()
            return try decoder.decode(T.self, from: data)
        } catch {
            if let json = String(data: data, encoding: .utf8) {
                let preview = json.prefix(2000)
                print("🔴 Decode failed for \(T.self): \(error)")
                print("🔴 JSON preview: \(preview)")
            }
            throw APIError.decodingError(error)
        }
    }

    func requestWithHeaders(
        method: String = "GET",
        uri: String,
        params: [String: String]? = nil,
        body: [String: Any]? = nil,
        requiresAuth: Bool = false
    ) async throws -> (Data, HTTPURLResponse) {
        guard var components = URLComponents(string: AppConstants.apiBaseURL + uri) else {
            throw APIError.invalidURL
        }

        if let params, !params.isEmpty {
            let existing = components.queryItems ?? []
            let newItems = params.map { URLQueryItem(name: $0.key, value: $0.value) }
            components.queryItems = existing + newItems
        }

        guard let url = components.url else { throw APIError.invalidURL }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = method

        if let authToken {
            urlRequest.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        }

        if let body {
            urlRequest.httpBody = try JSONSerialization.data(withJSONObject: body)
        }

        let (data, response) = try await session.data(for: urlRequest)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.noData
        }

        return (data, httpResponse)
    }
}

struct EmptyResponse: Decodable {
    init() {}
}
