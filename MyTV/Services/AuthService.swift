import Foundation
import SwiftData
import AuthenticationServices
#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#endif
import CryptoKit

enum AuthError: Error, LocalizedError {
    case missingClientID
    case noCode
    case noRefreshToken
    case noPresentationAnchor
    case sessionDidNotStart
    case sessionFailed(Error)

    var errorDescription: String? {
        switch self {
        case .missingClientID:
            return L10n.string("缺少 Trakt Client ID。请在 Xcode 的 MyTViOS target build setting 或 Run 环境变量中设置 TRAKT_CLIENT_ID。")
        case .noCode: return L10n.string("未获取到授权码")
        case .noRefreshToken: return L10n.string("无刷新 Token")
        case .noPresentationAnchor:
            return L10n.string("登录窗口尚未准备好，请稍后重试")
        case .sessionDidNotStart:
            return L10n.string("无法启动 Trakt 登录会话")
        case .sessionFailed(let err): return L10n.string("认证失败: %@", err.localizedDescription)
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
    private nonisolated let presentationAnchorStore = PresentationAnchorStore()

    func configure(modelContext: ModelContext) {
        self.modelContext = modelContext
        loadPersistedToken()
    }

    func updatePresentationAnchor(_ anchor: ASPresentationAnchor?) {
        presentationAnchorStore.set(anchor)
    }

    // MARK: - Login

    func login() async throws {
        guard AppConstants.isTraktClientIDConfigured else {
            throw AuthError.missingClientID
        }
        #if os(iOS)
        guard presentationAnchorStore.get() != nil else {
            throw AuthError.noPresentationAnchor
        }
        #endif

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
        guard let anchor = presentationAnchorStore.get() else {
            preconditionFailure("ASWebAuthenticationSession requested a presentation anchor before a window was registered.")
        }
        return anchor
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
        if !session.start() {
            holder.session = nil
            continuation.resume(throwing: AuthError.sessionDidNotStart)
        }
    }
}

private final class SessionHolder: @unchecked Sendable {
    var session: ASWebAuthenticationSession?
}

private final class PresentationAnchorStore: @unchecked Sendable {
    private let lock = NSLock()
    private weak var anchor: ASPresentationAnchor?

    func set(_ anchor: ASPresentationAnchor?) {
        lock.lock()
        self.anchor = anchor
        lock.unlock()
    }

    func get() -> ASPresentationAnchor? {
        lock.lock()
        defer { lock.unlock() }
        return anchor
    }
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
