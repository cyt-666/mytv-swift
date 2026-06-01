import Foundation

@MainActor enum AuthAPI {
    static func getToken(code: String, codeVerifier: String) async throws -> TokenDTO {
        try await TraktAPIClient.shared.request(
            method: "POST",
            uri: "/oauth/token",
            body: [
                "code": code,
                "client_id": AppConstants.clientID,
                "redirect_uri": AppConstants.redirectURI,
                "grant_type": "authorization_code",
                "code_verifier": codeVerifier
            ]
        )
    }

    static func refreshToken(_ refreshToken: String) async throws -> TokenDTO {
        try await TraktAPIClient.shared.request(
            method: "POST",
            uri: "/oauth/token",
            body: [
                "refresh_token": refreshToken,
                "client_id": AppConstants.clientID,
                "redirect_uri": AppConstants.redirectURI,
                "grant_type": "refresh_token"
            ]
        )
    }

    static func revokeToken(_ token: String) async throws {
        let _: EmptyResponse = try await TraktAPIClient.shared.request(
            method: "POST",
            uri: "/oauth/revoke",
            body: [
                "token": token,
                "client_id": AppConstants.clientID
            ]
        )
    }
}
