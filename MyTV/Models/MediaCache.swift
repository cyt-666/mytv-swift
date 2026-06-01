import Foundation
import SwiftData

@Model
final class MediaCache {
    @Attribute(.unique) var id: String
    var mediaType: String
    var traktId: Int
    var data: Data
    var updatedAt: Date
    var expiresAt: Date

    init(id: String, mediaType: String, traktId: Int, data: Data, updatedAt: Date = .now, expiresAt: Date) {
        self.id = id
        self.mediaType = mediaType
        self.traktId = traktId
        self.data = data
        self.updatedAt = updatedAt
        self.expiresAt = expiresAt
    }
}
