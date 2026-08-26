import XCTest
@testable import MyTV

final class HistoryViewModelTests: XCTestCase {
    func testHistoryFiltersMapToTraktHistoryTypes() {
        XCTAssertNil(HistoryViewModel.Filter.all.apiType)
        XCTAssertEqual(HistoryViewModel.Filter.movies.apiType, "movies")
        XCTAssertEqual(HistoryViewModel.Filter.shows.apiType, "shows")
    }

    func testHistoryFiltersKeepExpectedOrder() {
        XCTAssertEqual(
            HistoryViewModel.Filter.allCases,
            [.all, .movies, .shows]
        )
    }
}
