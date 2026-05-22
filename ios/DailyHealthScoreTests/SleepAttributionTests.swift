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

    func test_intervalEndingAfterWindow_isClippedToWindowEnd_withExplicitWindow() {
        let dayStart = date(2026, 5, 21, 0)
        // Pin the window explicitly so this test is independent of any default
        // and exercises the clipping mechanism directly. Window: 6 PM May 20
        // through noon May 21. Sample ends at 3 PM May 21 → attributed to
        // May 21 (end < dayEnd) but clipped at noon.
        let intervals = [interval(date(2026, 5, 20, 23), date(2026, 5, 21, 15))]
        let hours = SleepAttribution.attributedHours(
            intervals: intervals,
            dayStart: dayStart,
            windowHoursBefore: 6,
            windowHoursAfter: 12,
            calendar: calendar
        )
        // 11 PM May 20 → noon May 21 = 13 hours.
        XCTAssertEqual(hours, 13, accuracy: 1e-9)
    }

    /// Regression: when the user wakes up after noon, the *default* window
    /// must not clip the back end of the sleep. The previous default
    /// (`+12` = noon) was logging 6.7 h instead of 9 h 19 m for a user who
    /// slept until ~2:30 PM. The new default (`+18` = 6 PM) covers that.
    func test_defaultWindow_doesNotClipNineHourSleepEndingAfterNoon() {
        let dayStart = date(2026, 5, 22, 0)
        // 5:11 AM May 22 → 2:30 PM May 22 = 9 h 19 m.
        let bedtime = date(2026, 5, 22, 5, 11)
        let wakeup  = date(2026, 5, 22, 14, 30)
        let intervals = [interval(bedtime, wakeup)]
        let hours = SleepAttribution.attributedHours(
            intervals: intervals,
            dayStart: dayStart,
            calendar: calendar
        )
        XCTAssertEqual(hours, 9 + 19.0 / 60.0, accuracy: 1e-6)
    }

    /// Anyone genuinely sleeping past 6 PM is still capped at the default
    /// window — the cap is a safety net against runaway samples, not a hard
    /// limit we expect typical users to hit.
    func test_defaultWindow_clipsAtSixPM() {
        let dayStart = date(2026, 5, 22, 0)
        // Sample runs midnight → 8 PM May 22 (20 hours). Default windowEnd is
        // 6 PM → expect 18 hours.
        let intervals = [interval(date(2026, 5, 22, 0), date(2026, 5, 22, 20))]
        let hours = SleepAttribution.attributedHours(
            intervals: intervals,
            dayStart: dayStart,
            calendar: calendar
        )
        XCTAssertEqual(hours, 18, accuracy: 1e-9)
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

// MARK: - Session-based wake-day attribution (the May 22 9h-19m regression)

extension SleepAttributionTests {

    /// Reproduces the May 22, 2026 bug exactly. Apple Health reported a
    /// 9h 19m night that started at 8:34 PM (May 21) and ended at 5:53 AM
    /// (May 22). Apple Watch wrote the night as many short stage
    /// sub-samples — Core / REM / Deep — so a per-sample wake-day filter
    /// was discarding every sub-sample whose END fell before midnight
    /// May 22. The app was logging ~6.7 h instead of 9h 19m.
    ///
    /// The session-based attribution must include all of these stage
    /// sub-samples in May 22's total.
    func test_sessionAttribution_stageBlocksAcrossMidnight_areAllCounted() {
        let dayStart = date(2026, 5, 22, 0)
        // Reconstruction of the night, approximating the stage segmentation
        // visible in the Apple Health chart. All gaps are short (a few
        // minutes for Awake transitions).
        let intervals = [
            // Pre-midnight stages (these used to be silently dropped):
            interval(date(2026, 5, 21, 20, 34), date(2026, 5, 21, 21, 0)),   // Core
            interval(date(2026, 5, 21, 21, 0),  date(2026, 5, 21, 22, 30)),  // Core
            interval(date(2026, 5, 21, 22, 35), date(2026, 5, 21, 23, 0)),   // REM
            interval(date(2026, 5, 21, 23, 5),  date(2026, 5, 21, 23, 59)),  // Core
            // Post-midnight stages:
            interval(date(2026, 5, 22, 0,  0),  date(2026, 5, 22, 1, 30)),   // Core
            interval(date(2026, 5, 22, 1, 35),  date(2026, 5, 22, 2, 15)),   // REM
            interval(date(2026, 5, 22, 2, 20),  date(2026, 5, 22, 4, 0)),    // Core
            interval(date(2026, 5, 22, 4, 5),   date(2026, 5, 22, 4, 45)),   // Deep
            interval(date(2026, 5, 22, 4, 50),  date(2026, 5, 22, 5, 53)),   // REM
        ]
        let hours = SleepAttribution.attributedHours(
            intervals: intervals,
            dayStart: dayStart,
            calendar: calendar
        )
        // The asleep total is the union of all intervals — that's
        // 8:34 PM May 21 → 5:53 AM May 22 minus the brief Awake gaps.
        // Sum the explicit interval durations to compute the expected
        // value (each gap is exactly 5 minutes, four gaps total = 20 min,
        // plus a 5-minute pre-Core gap from 22:30→22:35 = 25 minutes of
        // Awake total).
        let expectedSeconds = intervals.reduce(0.0) { $0 + $1.end.timeIntervalSince($1.start) }
        XCTAssertEqual(hours, expectedSeconds / 3600.0, accuracy: 1e-6)
        // And the result must be well above the buggy ~6.7 (we expect ~8.8h
        // of asleep stages once pre-midnight blocks are restored).
        XCTAssertGreaterThan(hours, 8.5)
    }

    /// A genuinely separate nap is NOT lumped into the previous night's
    /// session — the gap is wider than the tolerance, so it becomes its
    /// own session. Both sessions end in the wake day, so the day total
    /// includes both — but they are counted as distinct sessions.
    func test_sessionAttribution_separateAfternoonNap_isOwnSession() {
        let dayStart = date(2026, 5, 22, 0)
        let nightStart = date(2026, 5, 21, 23, 0)
        let nightEnd   = date(2026, 5, 22, 6, 0)
        let napStart   = date(2026, 5, 22, 14, 0)
        let napEnd     = date(2026, 5, 22, 15, 0)
        let intervals = [
            interval(nightStart, nightEnd),
            interval(napStart, napEnd),
        ]
        let sessions = SleepAttribution.groupIntoSessions(intervals, gapTolerance: 60 * 60)
        XCTAssertEqual(sessions.count, 2, "8-hour gap must split into two sessions")

        let hours = SleepAttribution.attributedHours(
            intervals: intervals,
            dayStart: dayStart,
            calendar: calendar
        )
        XCTAssertEqual(hours, 7 + 1, accuracy: 1e-9)
    }

    /// A session whose END is in a *different* day (e.g. yesterday's nap
    /// that ended at 11 PM yesterday) must NOT contribute to today's
    /// total even though it overlaps the safety window.
    func test_sessionAttribution_sessionEndingPreviousDay_isExcluded() {
        let dayStart = date(2026, 5, 22, 0)
        // Yesterday's late-evening nap: 6 PM → 11 PM May 21. Ends before
        // midnight May 22 → not today's session.
        let intervals = [interval(date(2026, 5, 21, 18, 0), date(2026, 5, 21, 23, 0))]
        let hours = SleepAttribution.attributedHours(
            intervals: intervals,
            dayStart: dayStart,
            calendar: calendar
        )
        XCTAssertEqual(hours, 0, accuracy: 1e-9)
    }

    /// Brief Awake interruptions (under the gap tolerance) must NOT split
    /// a session, but the Awake time itself isn't added — only the asleep
    /// sub-samples are. So the total equals the sum of asleep durations,
    /// not the total bedtime.
    func test_sessionAttribution_briefAwakeGaps_doNotInflateOrSplit() {
        let dayStart = date(2026, 5, 22, 0)
        let intervals = [
            interval(date(2026, 5, 21, 23, 0), date(2026, 5, 22, 2, 0)),   // 3h
            // 10-minute Awake gap here (not in our intervals)
            interval(date(2026, 5, 22, 2, 10), date(2026, 5, 22, 5, 0)),   // 2h50m
        ]
        let hours = SleepAttribution.attributedHours(
            intervals: intervals,
            dayStart: dayStart,
            calendar: calendar
        )
        // Asleep total = 3 + (2 + 50/60) = 5h 50m. We must NOT inflate
        // by counting the 10-minute awake gap.
        XCTAssertEqual(hours, 3 + 2 + 50.0/60.0, accuracy: 1e-6)
    }
}
