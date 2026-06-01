import Foundation
import SwiftData

@Model
final class UserDataCache {
    @Attribute(.unique) var key: String
    var data: Data
    var updatedAt: Date
    var isDirty: Bool

    init(key: String, data: Data, updatedAt: Date = .now, isDirty: Bool = false) {
        self.key = key
        self.data = data
        self.updatedAt = updatedAt
        self.isDirty = isDirty
    }
}
