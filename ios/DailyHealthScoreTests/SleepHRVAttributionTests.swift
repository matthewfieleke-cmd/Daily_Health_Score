import XCTest
@testable import DailyHealthScore

final class SleepHRVAttributionTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    func test_averagesSamplesDuringAttributedSleepOnly() {
        let dayStart = calendar.date(from: DateComponents(year: 2026, month: 6, day: 9))!
        let sleep = SleepInterval(
            start: calendar.date(byAdding: .hour, value: -8, to: dayStart)!,
            end: calendar.date(byAdding: .hour, value: 7, to: dayStart)!
        )
        let samples = [
            HRVSample(
                timestamp: calendar.date(byAdding: .hour, value: 2, to: dayStart)!,
                sdnnMilliseconds: 40
            ),
            HRVSample(
                timestamp: calendar.date(byAdding: .hour, value: 4, to: dayStart)!,
                sdnnMilliseconds: 50
            ),
            HRVSample(
                timestamp: calendar.date(byAdding: .hour, value: 20, to: dayStart)!,
                sdnnMilliseconds: 99
            ),
        ]

        let average = SleepHRVAttribution.averageSDNNMs(
            samples: samples,
            asleepIntervals: [sleep],
            dayStart: dayStart,
            calendar: calendar
        )

        XCTAssertEqual(average, 45, accuracy: 0.001)
    }

    func test_returnsNilWhenNoSamplesDuringSleep() {
        let dayStart = calendar.date(from: DateComponents(year: 2026, month: 6, day: 9))!
        let sleep = SleepInterval(
            start: calendar.date(byAdding: .hour, value: -8, to: dayStart)!,
            end: calendar.date(byAdding: .hour, value: 7, to: dayStart)!
        )
        let samples = [
            HRVSample(
                timestamp: calendar.date(byAdding: .hour, value: 20, to: dayStart)!,
                sdnnMilliseconds: 50
            ),
        ]

        let average = SleepHRVAttribution.averageSDNNMs(
            samples: samples,
            asleepIntervals: [sleep],
            dayStart: dayStart,
            calendar: calendar
        )

        XCTAssertNil(average)
    }
}
