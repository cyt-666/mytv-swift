import Foundation
import XCTest
@testable import MyTV

final class MoviePilotEpisodeStateTests: XCTestCase {
    private let airedDate = "2024-01-01T00:00:00.000Z"
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    func testLibraryTakesPriorityOverDownloadAndSubscription() {
        let status = MoviePilotMediaStatus(
            subscriptions: [subscription(season: 1)],
            libraryItems: [library(season: 1, episodes: [2])],
            downloads: [download(seasonEpisode: "S01E02", state: "downloading")]
        )

        XCTAssertEqual(resolve(episode: 2, status: status), .inLibrary)
    }

    func testActiveDownloadTakesPriorityOverCompletedDownload() {
        let status = MoviePilotMediaStatus(
            downloads: [
                download(seasonEpisode: "S01E02", state: "completed"),
                download(seasonEpisode: "S01E02", state: "downloading")
            ]
        )

        XCTAssertEqual(resolve(episode: 2, status: status), .downloading)
    }

    func testCompletedDownloadIsPendingLibrary() {
        let status = MoviePilotMediaStatus(
            downloads: [download(seasonEpisode: "S01E02", state: "seeding")]
        )

        XCTAssertEqual(resolve(episode: 2, status: status), .pendingLibrary)
    }

    func testUnknownAirDateIsNotMarkedMissing() {
        XCTAssertEqual(resolve(episode: 2, firstAired: nil), .unaired)
    }

    func testSubscriptionPrecedesMissingForAiredEpisode() {
        let status = MoviePilotMediaStatus(subscriptions: [subscription(season: 1)])
        XCTAssertEqual(resolve(episode: 2, status: status), .subscribed)
    }

    func testAiredEpisodeWithoutMoviePilotStateIsMissing() {
        XCTAssertEqual(resolve(episode: 2), .missing)
    }

    func testSpecialSeasonIsIgnored() {
        XCTAssertNil(
            MoviePilotEpisodeStateResolver.state(
                season: 0,
                episode: 1,
                firstAired: airedDate,
                status: .empty,
                now: now
            )
        )
    }

    private func resolve(
        episode: Int,
        firstAired: String? = "2024-01-01T00:00:00.000Z",
        status: MoviePilotMediaStatus = .empty
    ) -> MoviePilotEpisodeState? {
        MoviePilotEpisodeStateResolver.state(
            season: 1,
            episode: episode,
            firstAired: firstAired,
            status: status,
            now: now
        )
    }

    private func subscription(season: Int?) -> MoviePilotSubscription {
        var payload: [String: Any] = [
            "id": 1,
            "name": "Test",
            "year": "2024",
            "type": "电视剧",
            "state": "R"
        ]
        payload["season"] = season
        return decode(MoviePilotSubscription.self, from: payload)
    }

    private func library(season: Int, episodes: [Int]) -> MoviePilotLibraryLookupItem {
        MoviePilotLibraryLookupItem(
            title: "Test",
            year: "2024",
            type: "电视剧",
            servers: [
                "default": MoviePilotLibraryServer(
                    exists: true,
                    seasons: [
                        String(season): MoviePilotLibrarySeason(
                            existingEpisodes: episodes,
                            totalEpisodes: episodes.count,
                            missingEpisodes: nil
                        )
                    ],
                    missingSeasons: nil
                )
            ]
        )
    }

    private func download(seasonEpisode: String, state: String) -> MoviePilotDownloadTask {
        decode(
            MoviePilotDownloadTask.self,
            from: [
                "downloader": "default",
                "hash": UUID().uuidString,
                "title": "Test \(seasonEpisode)",
                "year": "2024",
                "season_episode": seasonEpisode,
                "state": state
            ]
        )
    }

    private func decode<T: Decodable>(_ type: T.Type, from payload: [String: Any]) -> T {
        let data = try! JSONSerialization.data(withJSONObject: payload)
        return try! JSONDecoder().decode(type, from: data)
    }
}
