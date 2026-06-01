import Foundation
import SwiftData

@Model
final class APIResponseCache {
    @Attribute(.unique) var key: String
    var data: Data
    var updatedAt: Date
    var expiresAt: Date

    init(key: String, data: Data, updatedAt: Date = .now, expiresAt: Date) {
        self.key = key
        self.data = data
        self.updatedAt = updatedAt
        self.expiresAt = expiresAt
    }
}
