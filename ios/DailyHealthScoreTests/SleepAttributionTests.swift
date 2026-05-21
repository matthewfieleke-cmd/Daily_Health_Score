import XCTest
@testable import DailyHealthScore

final class SleepAttributionTests: XCTestCase {
    /// Use a fixed-timezone calendar so window math is deterministic across CI machines.
    private var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        return cal
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        return calendar.date(from: components)!
    }

    private func interval(_ s: Date, _ e: Date) -> SleepInterval {
        SleepInterval(start: s, end: e)
    }

    // MARK: - Empty / trivial cases

    func test_noIntervals_returnsZero() {
        let dayStart = date(2026, 5, 21, 0)
        XCTAssertEqual(
            SleepAttribution.attributedHours(intervals: [], dayStart: dayStart, calendar: calendar),
            0
        )
    }

    func test_singleSimpleNight_totalsCorrectly() {
        let dayStart = date(2026, 5, 21, 0)
        // Slept 11 PM May 20 → 6 AM May 21. End is on May 21 → counts for May 21.
        let intervals = [interval(date(2026, 5, 20, 23), date(2026, 5, 21, 6))]
        let hours = SleepAttribution.attributedHours(
            intervals: intervals,
            dayStart: dayStart,
            calendar: calendar
        )
        XCTAssertEqual(hours, 7, accuracy: 1e-9)
    }

    // MARK: - Wake-day attribution

    func test_intervalEndingPreviousDay_isExcluded() {
        let dayStart = date(2026, 5, 21, 0)
        // Slept 11 PM May 19 → 6 AM May 20. End is May 20, NOT May 21 → excluded.
        let intervals = [interval(date(2026, 5, 19, 23), date(2026, 5, 20, 6))]
        let hours = SleepAttribution.attributedHours(
            intervals: intervals,
            dayStart: dayStart,
            calendar: calendar
        )
        XCTAssertEqual(hours, 0, accuracy: 1e-9)
    }

    func test_intervalEndingNextDay_isExcluded() {
        let dayStart = date(2026, 5, 21, 0)
        // Slept 11 PM May 21 → 6 AM May 22. End is May 22 → not attributed to May 21.
        let intervals = [interval(date(2026, 5, 21, 23), date(2026, 5, 22, 6))]
        let hours = SleepAttribution.attributedHours(
            intervals: intervals,
            dayStart: dayStart,
            calendar: calendar
        )
        XCTAssertEqual(hours, 0, accuracy: 1e-9)
    }

    func test_intervalEndingExactlyAtDayStart_attributesToThatDay() {
        let dayStart = date(2026, 5, 21, 0)
        // End is exactly midnight at the start of May 21 → attributed to May 21 (half-open [dayStart, dayEnd)).
        let intervals = [interval(date(2026, 5, 20, 22), date(2026, 5, 21, 0))]
        let hours = SleepAttribution.attributedHours(
            intervals: intervals,
            dayStart: dayStart,
            calendar: calendar
        )
        XCTAssertEqual(hours, 2, accuracy: 1e-9)
    }

    // MARK: - Window clipping

    func test_intervalStartingBeforeWindow_isClippedToWindowStart() {
        let dayStart = date(2026, 5, 21, 0)
        // Window starts 6 PM May 20. Sample starts at 3 PM May 20 → 3 lost hours.
        let intervals = [interval(date(2026, 5, 20, 15), date(2026, 5, 21, 6))]
        let hours = SleepAttribution.attributedHours(
            intervals: intervals,
            dayStart: dayStart,
            calendar: calendar
        )
        // 6 PM May 20 → 6 AM May 21 = 12 hours.
        XCTAssertEqual(hours, 12, accuracy: 1e-9)
    }

    func test_intervalEndingAfterWindow_isClippedToWindowEnd() {
        let dayStart = date(2026, 5, 21, 0)
        // Window ends noon May 21. Sample ends at 3 PM May 21 → still attributed to May 21 (end < dayEnd),
        // but the segment after noon is clipped off.
        let intervals = [interval(date(2026, 5, 20, 23), date(2026, 5, 21, 15))]
        let hours = SleepAttribution.attributedHours(
            intervals: intervals,
            dayStart: dayStart,
            calendar: calendar
        )
        // 11 PM May 20 → noon May 21 = 13 hours.
        XCTAssertEqual(hours, 13, accuracy: 1e-9)
    }

    // MARK: - Overlap merging (the screenshot regression)

    /// This is the key test. Apple Health "Time Asleep" on the Summary widget shows the
    /// merged-union of asleep periods across sources; if the iPhone *and* AutoSleep both
    /// record the same night, summing them naively doubles the total. We must merge.
    func test_overlappingIntervalsFromMultipleSources_areMergedNotDoubleCounted() {
        let dayStart = date(2026, 5, 21, 0)
        // Source A (e.g., Apple Watch): 11:00 PM → 4:00 AM (5 hours)
        // Source B (e.g., AutoSleep):    1:00 AM → 5:00 AM (4 hours, overlaps A by 3h)
        // Naive sum: 9 hours. Correct (union): 11 PM → 5 AM = 6 hours.
        let intervals = [
            interval(date(2026, 5, 20, 23), date(2026, 5, 21, 4)),
            interval(date(2026, 5, 21, 1), date(2026, 5, 21, 5)),
        ]
        let hours = SleepAttribution.attributedHours(
            intervals: intervals,
            dayStart: dayStart,
            calendar: calendar
        )
        XCTAssertEqual(hours, 6, accuracy: 1e-9)
    }

    /// Reproduce the screenshot case (Time Asleep = 4h 56m, wake ~6:00 AM) where two sources
    /// log the same night. The union total must equal what Apple Health displays.
    func test_screenshotScenario_matchesAppleHealthTotal() {
        let dayStart = date(2026, 5, 21, 0)
        // 4h 56m of sleep ending at 6:00 AM = started at 1:04 AM.
        let nightStart = date(2026, 5, 21, 1, 4)
        let nightEnd = date(2026, 5, 21, 6, 0)
        // Two sources log the same night with slightly different boundaries.
        let intervals = [
            interval(nightStart, nightEnd),
            interval(date(2026, 5, 21, 1, 10), date(2026, 5, 21, 5, 55)),
        ]
        let hours = SleepAttribution.attributedHours(
            intervals: intervals,
            dayStart: dayStart,
            calendar: calendar
        )
        let expectedMinutes = nightEnd.timeIntervalSince(nightStart) / 60.0
        XCTAssertEqual(hours * 60.0, expectedMinutes, accuracy: 0.001)
        // Sanity: must equal exactly 4 hours 56 minutes.
        XCTAssertEqual(hours, 4.0 + 56.0 / 60.0, accuracy: 1e-9)
    }

    func test_adjacentTouchingIntervals_areMergedWithoutGap() {
        let dayStart = date(2026, 5, 21, 0)
        // 11 PM → 2 AM, then 2 AM → 4 AM. They touch at 2 AM exactly.
        let intervals = [
            interval(date(2026, 5, 20, 23), date(2026, 5, 21, 2)),
            interval(date(2026, 5, 21, 2), date(2026, 5, 21, 4)),
        ]
        let hours = SleepAttribution.attributedHours(
            intervals: intervals,
            dayStart: dayStart,
            calendar: calendar
        )
        XCTAssertEqual(hours, 5, accuracy: 1e-9)
    }

    func test_nonOverlappingIntervals_sumNormally() {
        let dayStart = date(2026, 5, 21, 0)
        // Main night: 11 PM → 4 AM (5h). Brief wake then nap: 5 AM → 6 AM (1h).
        let intervals = [
            interval(date(2026, 5, 20, 23), date(2026, 5, 21, 4)),
            interval(date(2026, 5, 21, 5), date(2026, 5, 21, 6)),
        ]
        let hours = SleepAttribution.attributedHours(
            intervals: intervals,
            dayStart: dayStart,
            calendar: calendar
        )
        XCTAssertEqual(hours, 6, accuracy: 1e-9)
    }

    // MARK: - mergeOverlapping (white-box)

    func test_mergeOverlapping_emptyAndSingle_passThrough() {
        XCTAssertTrue(SleepAttribution.mergeOverlapping([]).isEmpty)
        let solo = [interval(date(2026, 5, 21, 0), date(2026, 5, 21, 1))]
        XCTAssertEqual(SleepAttribution.mergeOverlapping(solo), solo)
    }

    func test_mergeOverlapping_unorderedInput_isSortedThenMerged() {
        // Provided out of order; result must be sorted by start and merged.
        let a = interval(date(2026, 5, 21, 5), date(2026, 5, 21, 6))
        let b = interval(date(2026, 5, 21, 1), date(2026, 5, 21, 3))
        let c = interval(date(2026, 5, 21, 2), date(2026, 5, 21, 4))
        let merged = SleepAttribution.mergeOverlapping([a, b, c])
        XCTAssertEqual(merged.count, 2)
        XCTAssertEqual(merged[0].start, date(2026, 5, 21, 1))
        XCTAssertEqual(merged[0].end, date(2026, 5, 21, 4))
        XCTAssertEqual(merged[1].start, date(2026, 5, 21, 5))
        XCTAssertEqual(merged[1].end, date(2026, 5, 21, 6))
    }

    func test_mergeOverlapping_fullyContainedInterval_disappearsIntoOuter() {
        let outer = interval(date(2026, 5, 21, 0), date(2026, 5, 21, 8))
        let inner = interval(date(2026, 5, 21, 2), date(2026, 5, 21, 5))
        let merged = SleepAttribution.mergeOverlapping([outer, inner])
        XCTAssertEqual(merged, [outer])
    }
}
