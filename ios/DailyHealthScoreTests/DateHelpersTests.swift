import XCTest
@testable import DailyHealthScore

final class DateHelpersTests: XCTestCase {
    private var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        return cal
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 12, _ minute: Int = 0) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        return calendar.date(from: components)!
    }

    func test_localDateKey_padsMonthAndDay() {
        // DateHelpers uses Calendar.current which we can't override here, but the format pattern is
        // deterministic for a given Date.
        let key = DateHelpers.localDateKey(from: date(2026, 1, 5))
        // Format is "yyyy-MM-dd"; both pieces are zero-padded.
        XCTAssertEqual(key.count, 10)
        XCTAssertEqual(key.split(separator: "-").count, 3)
        let parts = key.split(separator: "-")
        XCTAssertEqual(parts[0].count, 4)
        XCTAssertEqual(parts[1].count, 2)
        XCTAssertEqual(parts[2].count, 2)
    }

    func test_dateFromKey_parsesValidKey() {
        let parsed = DateHelpers.date(from: "2026-05-21")
        XCTAssertNotNil(parsed)
        let comps = Calendar.current.dateComponents([.year, .month, .day], from: parsed!)
        XCTAssertEqual(comps.year, 2026)
        XCTAssertEqual(comps.month, 5)
        XCTAssertEqual(comps.day, 21)
    }

    func test_dateFromKey_rejectsMalformedKeys() {
        XCTAssertNil(DateHelpers.date(from: "2026/05/21"))
        XCTAssertNil(DateHelpers.date(from: "20260521"))
        XCTAssertNil(DateHelpers.date(from: "2026-05"))
        XCTAssertNil(DateHelpers.date(from: ""))
        XCTAssertNil(DateHelpers.date(from: "not a date"))
    }

    func test_addDays_forward() {
        XCTAssertEqual(DateHelpers.addDays(to: "2026-05-21", days: 1), "2026-05-22")
        // Month rollover
        XCTAssertEqual(DateHelpers.addDays(to: "2026-05-31", days: 1), "2026-06-01")
        // Year rollover
        XCTAssertEqual(DateHelpers.addDays(to: "2026-12-31", days: 1), "2027-01-01")
    }

    func test_addDays_backward() {
        XCTAssertEqual(DateHelpers.addDays(to: "2026-05-21", days: -1), "2026-05-20")
        XCTAssertEqual(DateHelpers.addDays(to: "2026-01-01", days: -1), "2025-12-31")
    }

    func test_addDays_invalidKeyReturnsNil() {
        XCTAssertNil(DateHelpers.addDays(to: "not-a-date", days: 1))
    }

    func test_rollingDateKeys_includesAnchorAndCountIsExact() {
        let anchor = date(2026, 5, 21)
        let keys = DateHelpers.rollingDateKeys(days: 7, endingOn: anchor)
        XCTAssertEqual(keys.count, 7)
        // Last key should be the anchor day; first should be 6 days earlier.
        XCTAssertEqual(keys.last, DateHelpers.localDateKey(from: anchor))
        XCTAssertEqual(
            keys.first,
            DateHelpers.localDateKey(from: Calendar.current.date(byAdding: .day, value: -6, to: anchor)!)
        )
    }

    func test_rollingDateKeys_returnsKeysInChronologicalOrder() {
        let anchor = date(2026, 5, 21)
        let keys = DateHelpers.rollingDateKeys(days: 30, endingOn: anchor)
        XCTAssertEqual(keys.count, 30)
        let sorted = keys.sorted()
        XCTAssertEqual(keys, sorted)
    }
}
