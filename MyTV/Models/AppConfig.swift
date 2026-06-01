import Foundation
import SwiftData

@Model
final class AppConfig {
    @Attribute(.unique) var key: String
    var value: Data
    var updatedAt: Date

    init(key: String, value: Data, updatedAt: Date = .now) {
        self.key = key
        self.value = value
        self.updatedAt = updatedAt
    }
}
