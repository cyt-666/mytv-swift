import Foundation

struct TokenDTO: Codable {
    let accessToken: String
    let tokenType: String
    let expiresIn: Int
    let refreshToken: String
    let scope: String
    let createdAt: Int

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case tokenType = "token_type"
        case expiresIn = "expires_in"
        case refreshToken = "refresh_token"
        case scope
        case createdAt = "created_at"
    }

    var isExpired: Bool {
        let expiryTimestamp = createdAt + expiresIn
        let now = Int(Date().timeIntervalSince1970)
        return now >= expiryTimestamp
    }

    var authorizationHeader: String {
        "\(tokenType) \(accessToken)"
    }
}
