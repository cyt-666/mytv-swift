import Foundation
import SwiftData
import AuthenticationServices
import CryptoKit

enum AuthError: Error, LocalizedError {
    case noCode
    case noRefreshToken
    case sessionFailed(Error)

    var errorDescription: String? {
        switch self {
        case .noCode: return "未获取到授权码"
        case .noRefreshToken: return "无刷新 Token"
        case .sessionFailed(let err): return "认证失败: \(err.localizedDescription)"
        }
    }
}

@Observable
@MainActor
final class AuthService: NSObject, ASWebAuthenticationPresentationContextProviding {
    static let shared = AuthService()

    private(set) var currentToken: TokenDTO?
    private(set) var isLoggedIn = false
    private(set) var userProfile: UserProfileDTO?

    private var modelContext: ModelContext?
    private var codeVerifier: String?

    func configure(modelContext: ModelContext) {
        self.modelContext = modelContext
        loadPersistedToken()
    }

    // MARK: - Login

    func login() async throws {
        let verifier = Self.generateCodeVerifier()
        self.codeVerifier = verifier
        let challenge = Self.codeChallenge(from: verifier)

        let authURL = URL(string: "\(AppConstants.traktHost)/oauth/authorize")!
            .appending(queryItems: [
                URLQueryItem(name: "client_id", value: AppConstants.clientID),
                URLQueryItem(name: "redirect_uri", value: AppConstants.redirectURI),
                URLQueryItem(name: "response_type", value: "code"),
                URLQueryItem(name: "code_challenge", value: challenge),
                URLQueryItem(name: "code_challenge_method", value: "S256")
            ])

        let code: String = try await runAuthSession(url: authURL, provider: self)

        let token = try await AuthAPI.getToken(code: code, codeVerifier: verifier)
        try persistToken(token)
        await TraktAPIClient.shared.setAuthToken(token.accessToken)
        self.currentToken = token
        self.codeVerifier = nil
        self.isLoggedIn = true
        await fetchProfile()
    }

    // MARK: - Refresh

    func refreshToken() async throws {
        guard let refreshToken = currentToken?.refreshToken else {
            throw AuthError.noRefreshToken
        }
        let token = try await AuthAPI.refreshToken(refreshToken)
        try persistToken(token)
        await TraktAPIClient.shared.setAuthToken(token.accessToken)
        self.currentToken = token
        self.isLoggedIn = true
    }

    // MARK: - Logout

    func logout() async throws {
        if let token = currentToken?.accessToken {
            try? await AuthAPI.revokeToken(token)
        }
        try deletePersistedToken()
        await TraktAPIClient.shared.setAuthToken(nil)
        self.currentToken = nil
        self.isLoggedIn = false
        self.userProfile = nil
    }

    func fetchProfile() async {
        do {
            self.userProfile = try await UserAPI.profile()
        } catch {
            print("获取用户资料失败: \(error)")
        }
    }

    // MARK: - ASWebAuthenticationPresentationContextProviding

    nonisolated func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        MainActor.assumeIsolated {
            NSApplication.shared.mainWindow ?? NSApplication.shared.windows.first ?? NSWindow()
        }
    }

    // MARK: - PKCE

    private static func generateCodeVerifier() -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return Data(bytes).base64URLEncodedString()
    }

    private static func codeChallenge(from verifier: String) -> String {
        let data = Data(verifier.utf8)
        let hash = SHA256.hash(data: data)
        return Data(hash).base64URLEncodedString()
    }

    // MARK: - Persistence

    private func persistToken(_ token: TokenDTO) throws {
        guard let modelContext else { return }
        let data = try JSONEncoder().encode(token)
        try modelContext.delete(model: AppConfig.self, where: #Predicate { $0.key == "token" })
        let config = AppConfig(key: "token", value: data)
        modelContext.insert(config)
        try modelContext.save()
    }

    private func loadPersistedToken() {
        guard let modelContext else { return }
        let descriptor = FetchDescriptor<AppConfig>(predicate: #Predicate { $0.key == "token" })
        guard let configs = try? modelContext.fetch(descriptor),
              let config = configs.first,
              let token = try? JSONDecoder().decode(TokenDTO.self, from: config.value) else {
            return
        }
        self.currentToken = token
        self.isLoggedIn = !token.isExpired
        // Always set auth token so 401-retry refresh flow works
        Task {
            await TraktAPIClient.shared.setAuthToken(token.accessToken)
            if !token.isExpired {
                await fetchProfile()
            } else {
                // Token expired, try refresh
                try? await refreshToken()
            }
        }
    }

    private func deletePersistedToken() throws {
        guard let modelContext else { return }
        try modelContext.delete(model: AppConfig.self, where: #Predicate { $0.key == "token" })
        try modelContext.save()
    }
}

// MARK: - Auth session (nonisolated, runs on Safari's XPC thread)

private func runAuthSession(
    url: URL,
    provider: ASWebAuthenticationPresentationContextProviding
) async throws -> String {
    let holder = SessionHolder()
    return try await withCheckedThrowingContinuation { continuation in
        let session = ASWebAuthenticationSession(
            url: url,
            callbackURLScheme: AppConstants.callbackScheme
        ) { callbackURL, error in
            holder.session = nil
            if let error = error as? ASWebAuthenticationSessionError,
               error.code == .canceledLogin {
                continuation.resume(throwing: AuthError.sessionFailed(error))
                return
            }
            if let error {
                continuation.resume(throwing: AuthError.sessionFailed(error))
                return
            }
            guard let url = callbackURL,
                  let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
                  let code = components.queryItems?.first(where: { $0.name == "code" })?.value
            else {
                continuation.resume(throwing: AuthError.noCode)
                return
            }
            continuation.resume(returning: code)
        }
        session.presentationContextProvider = provider
        session.prefersEphemeralWebBrowserSession = false
        holder.session = session
        session.start()
    }
}

private final class SessionHolder: @unchecked Sendable {
    var session: ASWebAuthenticationSession?
}

// MARK: - Base64URL

private extension Data {
    func base64URLEncodedString() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
