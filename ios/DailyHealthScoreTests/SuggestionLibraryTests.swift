import XCTest
@testable import DailyHealthScore

final class SuggestionLibraryTests: XCTestCase {
    func test_dayPools_haveAtLeastFifteenEntriesPerFocus() {
        for focus in PrimaryFocus.allCases {
            let pool = SuggestionLibrary.pool(for: focus, phase: .day)
            XCTAssertGreaterThanOrEqual(pool.count, 15, "day pool for \(focus)")
            XCTAssertTrue(pool.allSatisfy { $0.id.contains("-day-") }, "day pool ids for \(focus)")
        }
    }

    func test_dayFiberSuggestions_doNotStartWithTomorrow() {
        let pool = SuggestionLibrary.pool(for: .fiber, phase: .day)
        for entry in pool {
            XCTAssertFalse(
                entry.text.hasPrefix("Tomorrow"),
                "daytime fiber tip should be for today: \(entry.id)"
            )
        }
    }

    func test_eveningFiberSuggestions_includeTomorrowStyle() {
        let pool = SuggestionLibrary.pool(for: .fiber, phase: .evening)
        XCTAssertTrue(pool.contains { $0.text.hasPrefix("Tomorrow") })
    }
}
