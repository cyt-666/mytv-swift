import XCTest
@testable import MyTV

final class MoviePilotSearchModelsTests: XCTestCase {
    func testDecodesSearchSummaryAndFilterOptions() throws {
        let text = """
        {
          "total_count": 12,
          "message": "搜索完成",
          "all_sites": [{"id": 1, "name": "Site A"}],
          "search_site_ids": [1],
          "filter_options": {
            "site": ["Site A"],
            "season": ["S01E02"],
            "freeState": ["Free"],
            "edition": ["BluRay"],
            "resolution": ["1080p"],
            "videoCode": ["H265"],
            "releaseGroup": ["Group"]
          }
        }
        """

        let summary = try MoviePilotToolTextDecoder.decode(
            MoviePilotTorrentSearchSummary.self,
            from: text
        )

        XCTAssertEqual(summary.totalCount, 12)
        XCTAssertEqual(summary.filterOptions.season, ["S01E02"])
        XCTAssertEqual(summary.filterOptions.releaseGroup, ["Group"])
    }

    func testDecodesEmbeddedSearchPage() throws {
        let text = """
        搜索结果如下：
        {
          "total_count": 1,
          "page": 1,
          "total_pages": 1,
          "results": [{
            "torrent_info": {
              "title": "Show S01E02 1080p",
              "size": "2.0 GB",
              "seeders": 12,
              "peers": 3,
              "site_name": "Site A",
              "torrent_url": "abcdef0:1"
            },
            "media_info": {
              "title": "Show",
              "year": "2024",
              "type": "电视剧",
              "season": 1,
              "tmdb_id": 10
            },
            "meta_info": {
              "name": "Show",
              "season_episode": "S01E02",
              "video_encode": "H265",
              "resource_pix": "1080p"
            }
          }]
        }
        """

        let page = try MoviePilotToolTextDecoder.decode(
            MoviePilotTorrentSearchPage.self,
            from: text
        )

        XCTAssertEqual(page.totalCount, 1)
        XCTAssertEqual(page.results.first?.torrentInfo?.torrentURL, "abcdef0:1")
    }

    func testEpisodeMatchPriorityKeepsAmbiguousResultsVisible() throws {
        let exact = try result(seasonEpisode: "S01E02")
        let seasonPack = try result(seasonEpisode: "S01")
        let ambiguous = try result(seasonEpisode: nil)

        XCTAssertEqual(exact.matchPriority(season: 1, episode: 2), 0)
        XCTAssertEqual(seasonPack.matchPriority(season: 1, episode: 2), 1)
        XCTAssertEqual(ambiguous.matchPriority(season: 1, episode: 2), 3)
    }

    func testEmptyToolTextThrowsInsteadOfBecomingSuccess() {
        XCTAssertThrowsError(
            try MoviePilotToolTextDecoder.decode(
                MoviePilotTorrentSearchPage.self,
                from: "   "
            )
        )
    }

    func testLibraryNotFoundTextDecodesAsEmptyArray() throws {
        let items = try MoviePilotToolTextDecoder.decodeArray(
            MoviePilotLibraryLookupItem.self,
            from: "媒体库中未找到相关媒体"
        )

        XCTAssertTrue(items.isEmpty)
    }

    func testPlainTextToolErrorIsNotDecodedAsEmptyArray() {
        XCTAssertThrowsError(
            try MoviePilotToolTextDecoder.decodeArray(
                MoviePilotLibraryLookupItem.self,
                from: "查询媒体库时发生错误: timeout"
            )
        )
    }

    func testCachedSnapshotFiltersAndPaginatesLocally() throws {
        let snapshot = try cachedSnapshot()
        var filters = MoviePilotSearchFilters()
        filters.sites = ["Site A"]
        filters.resolutions = ["1080p"]

        let firstPage = snapshot.page(
            filters: filters,
            requestedPage: 1,
            pageSize: 1
        )
        let secondPage = snapshot.page(
            filters: filters,
            requestedPage: 2,
            pageSize: 1
        )

        XCTAssertEqual(firstPage.totalCount, 2)
        XCTAssertEqual(firstPage.totalPages, 2)
        XCTAssertEqual(firstPage.results.first?.torrentInfo?.title, "Show S01E01 1080p")
        XCTAssertEqual(secondPage.results.first?.torrentInfo?.title, "Show S01E02 1080p")
    }

    func testCachedSnapshotCodableRoundTrip() throws {
        let snapshot = try cachedSnapshot()
        let data = try JSONEncoder().encode(snapshot)
        let decoded = try JSONDecoder().decode(
            MoviePilotResourceSearchSnapshot.self,
            from: data
        )

        XCTAssertEqual(decoded.results.count, 3)
        XCTAssertEqual(decoded.summary.totalCount, 3)
        XCTAssertEqual(decoded.cachedAt, snapshot.cachedAt)
    }

    private func result(seasonEpisode: String?) throws -> MoviePilotTorrentSearchResult {
        let seasonValue = seasonEpisode.map { "\"\($0)\"" } ?? "null"
        let text = """
        {
          "torrent_info": {
            "title": "Show",
            "torrent_url": "abcdef0:1"
          },
          "meta_info": {
            "season_episode": \(seasonValue)
          }
        }
        """
        return try MoviePilotToolTextDecoder.decode(
            MoviePilotTorrentSearchResult.self,
            from: text
        )
    }

    private func cachedSnapshot() throws -> MoviePilotResourceSearchSnapshot {
        let summary = try MoviePilotToolTextDecoder.decode(
            MoviePilotTorrentSearchSummary.self,
            from: """
            {
              "total_count": 3,
              "filter_options": {
                "site": ["Site A", "Site B"],
                "season": ["S01E01", "S01E02"],
                "resolution": ["1080p", "2160p"]
              }
            }
            """
        )
        let page = try MoviePilotToolTextDecoder.decode(
            MoviePilotTorrentSearchPage.self,
            from: """
            {
              "total_count": 3,
              "page": 1,
              "total_pages": 1,
              "results": [
                {
                  "torrent_info": {
                    "title": "Show S01E01 1080p",
                    "site_name": "Site A",
                    "torrent_url": "aaaaaaa:1"
                  },
                  "meta_info": {
                    "season_episode": "S01E01",
                    "resource_pix": "1080p"
                  }
                },
                {
                  "torrent_info": {
                    "title": "Show S01E02 1080p",
                    "site_name": "Site A",
                    "torrent_url": "bbbbbbb:2"
                  },
                  "meta_info": {
                    "season_episode": "S01E02",
                    "resource_pix": "1080p"
                  }
                },
                {
                  "torrent_info": {
                    "title": "Show S01 2160p",
                    "site_name": "Site B",
                    "torrent_url": "ccccccc:3"
                  },
                  "meta_info": {
                    "season_episode": "S01",
                    "resource_pix": "2160p"
                  }
                }
              ]
            }
            """
        )
        return MoviePilotResourceSearchSnapshot(
            summary: summary,
            results: page.results,
            cachedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
    }
}
