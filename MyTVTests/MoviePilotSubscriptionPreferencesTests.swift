import XCTest
@testable import MyTV

final class MoviePilotSubscriptionPreferencesTests: XCTestCase {
    func testDefaultPresetAddsNoFilters() {
        let preferences = MoviePilotSubscriptionPreferences.default

        XCTAssertNil(preferences.resolvedQuality)
        XCTAssertNil(preferences.resolvedResolution)
        XCTAssertNil(preferences.resolvedEffect)
        XCTAssertNil(preferences.resolvedSiteIDs)
        XCTAssertNil(preferences.resolvedFilterGroupNames)
    }

    func testBuiltInPresetsResolveExpectedPatterns() {
        var preferences = MoviePilotSubscriptionPreferences.default
        preferences.preset = .fullHD
        XCTAssertEqual(preferences.resolvedResolution, "1080p|1080i")

        preferences.preset = .ultraHD
        XCTAssertEqual(preferences.resolvedResolution, "2160p|4K|UHD")
        XCTAssertNil(preferences.resolvedEffect)

        preferences.preset = .ultraHDHDR
        XCTAssertEqual(preferences.resolvedResolution, "2160p|4K|UHD")
        XCTAssertTrue(preferences.resolvedEffect?.contains("Dolby Vision") == true)
    }

    func testCustomPresetTrimsFieldsAndSortsSelections() {
        var preferences = MoviePilotSubscriptionPreferences.default
        preferences.preset = .custom
        preferences.customQuality = "  BluRay|WEB-DL  "
        preferences.customResolution = " 1080p "
        preferences.customEffect = " HDR|DV "
        preferences.siteIDs = [9, 2]
        preferences.filterGroupNames = ["Z", "A"]

        XCTAssertEqual(preferences.resolvedQuality, "BluRay|WEB-DL")
        XCTAssertEqual(preferences.resolvedResolution, "1080p")
        XCTAssertEqual(preferences.resolvedEffect, "HDR|DV")
        XCTAssertEqual(preferences.resolvedSiteIDs, [2, 9])
        XCTAssertEqual(preferences.resolvedFilterGroupNames, ["A", "Z"])
    }

    func testPreferencesCodableRoundTrip() throws {
        var original = MoviePilotSubscriptionPreferences.default
        original.preset = .custom
        original.customQuality = "BluRay"
        original.siteIDs = [1, 2]
        original.filterGroupNames = ["Anime"]

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(
            MoviePilotSubscriptionPreferences.self,
            from: data
        )

        XCTAssertEqual(decoded, original)
    }

    func testDecodesRuleGroupResponse() throws {
        let response = try MoviePilotToolTextDecoder.decode(
            MoviePilotRuleGroupResponse.self,
            from: """
            {
              "success": true,
              "message": "找到 1 个规则组",
              "count": 1,
              "rule_groups": [{
                "name": "高清优先",
                "description": "Test",
                "rule_string": "resolution"
              }]
            }
            """
        )

        XCTAssertTrue(response.success)
        XCTAssertEqual(response.ruleGroups.first?.name, "高清优先")
    }
}
