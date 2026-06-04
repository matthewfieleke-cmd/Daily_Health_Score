import XCTest
@testable import DailyHealthScore

final class DayPhaseTests: XCTestCase {
    private var calendar: Calendar!

    override func setUp() {
        super.setUp()
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "America/Chicago")!
        calendar = cal
    }

    func test_before730PM_isDay() {
        var components = DateComponents()
        components.year = 2026
        components.month = 5
        components.day = 31
        components.hour = 10
        components.minute = 30
        let date = calendar.date(from: components)!
        XCTAssertEqual(DayPhase.current(from: date, calendar: calendar), .day)
    }

    func test_at730PM_isEvening() {
        var components = DateComponents()
        components.year = 2026
        components.month = 5
        components.day = 31
        components.hour = 19
        components.minute = 30
        let date = calendar.date(from: components)!
        XCTAssertEqual(DayPhase.current(from: date, calendar: calendar), .evening)
    }

    func test_at729PM_isDay() {
        var components = DateComponents()
        components.year = 2026
        components.month = 5
        components.day = 31
        components.hour = 19
        components.minute = 29
        let date = calendar.date(from: components)!
        XCTAssertEqual(DayPhase.current(from: date, calendar: calendar), .day)
    }
}
