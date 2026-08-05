import XCTest
@testable import MyTV

final class ImagesDTOTests: XCTestCase {
    func testPreferredPosterURLUsesFirstNonEmptyPoster() {
        let images = makeImages(
            poster: ["  ", "media.trakt.tv/poster.webp"],
            fanart: ["media.trakt.tv/fanart.webp"]
        )

        XCTAssertEqual(images.preferredPosterURL, "media.trakt.tv/poster.webp")
    }

    func testPreferredPosterURLFallsBackWhenPosterIsMissing() {
        let images = makeImages(
            fanart: ["media.trakt.tv/fanart.webp"],
            thumb: ["media.trakt.tv/thumb.webp"]
        )

        XCTAssertEqual(images.preferredPosterURL, "media.trakt.tv/thumb.webp")
    }

    private func makeImages(
        poster: [String]? = nil,
        fanart: [String]? = nil,
        banner: [String]? = nil,
        thumb: [String]? = nil,
        screenshot: [String]? = nil
    ) -> ImagesDTO {
        ImagesDTO(
            poster: poster,
            fanart: fanart,
            banner: banner,
            thumb: thumb,
            logo: nil,
            clearart: nil,
            screenshot: screenshot
        )
    }
}
