import Foundation
import SwiftData

@Model
final class TranslationCache {
    @Attribute(.unique) var id: String
    var title: String?
    var overview: String?
    var tagline: String?
    var updatedAt: Date
    var expiresAt: Date

    init(id: String, title: String?, overview: String?, tagline: String?, updatedAt: Date = .now, expiresAt: Date) {
        self.id = id
        self.title = title
        self.overview = overview
        self.tagline = tagline
        self.updatedAt = updatedAt
        self.expiresAt = expiresAt
    }
}
