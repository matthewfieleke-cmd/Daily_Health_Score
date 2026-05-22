import Foundation

/// A half-open `[start, end)` time interval representing one period of recorded
/// asleep time (already filtered to an "asleep" `HKCategoryValueSleepAnalysis`).
struct SleepInterval: Equatable {
    var start: Date
    var end: Date
}

/// Pure helpers that attribute raw HealthKit asleep intervals to a calendar
/// day and total them.
///
/// This logic is separated from `HealthKitService` so it can be unit-tested
/// without HealthKit. The HealthKit query in `HealthKitService.fetchSleepHours`
/// produces `[SleepInterval]` and hands them here.
///
/// Three behaviors that make our totals line up with Apple Health's
/// "Time Asleep" summary:
///
/// 1. **Session-based wake-day attribution.** Apple Watch (watchOS 9+) records
///    sleep as many short *stage* sub-samples — one per Core/Deep/REM block.
///    If the user's bedtime started before midnight (the common case), many
///    of those sub-samples end *before* the wake calendar day even begins.
///    Filtering per sub-sample would silently drop the early-night stages
///    and produce a total far smaller than Apple Health's. Instead we group
///    sub-samples into one logical "sleep session" (allowing short Awake
///    gaps inside a session) and attribute the **entire session** to the
///    wake day based on when the session **ended**.
/// 2. **Interval merging.** Overlapping intervals from different HealthKit
///    sources (Apple Watch + AutoSleep + iPhone, etc.) are merged into a
///    union before summing, so the same stretch of time isn't counted twice.
/// 3. **Window clipping.** As a safety net, the union is clipped to a wide
///    `[windowStart, windowEnd]` window around the wake day so a runaway
///    sample (e.g. a 24-hour artifact) can't credit absurd amounts of sleep.
enum SleepAttribution {
    /// Hours of asleep time attributed to the wake day starting at `dayStart`.
    ///
    /// - parameter intervals: every "asleep" sample's `[start, end)`, from any
    ///   number of HealthKit sources. Caller filters to asleep category values.
    /// - parameter dayStart: midnight (local) of the wake day to attribute to.
    /// - parameter windowHoursBefore: how many hours before `dayStart` are
    ///   eligible to be included (default 6 → 6:00 PM the prior day).
    /// - parameter windowHoursAfter: how many hours after `dayStart` are
    ///   eligible to be included (default 18 → 6:00 PM of the wake day).
    ///   This is intentionally generous so that late wake-ups, weekend
    ///   sleep-ins, and post-night-shift recovery sleep all count toward
    ///   the wake day. Apple Health's "Time Asleep" widget uses the user's
    ///   defined sleep schedule (not exposed by HealthKit to third-party
    ///   apps); a wide window keeps our totals in step for both typical
    ///   and atypical schedules.
    /// - parameter sessionGapToleranceMinutes: maximum gap between adjacent
    ///   asleep sub-samples that still counts as the same logical session.
    ///   Apple Watch interleaves brief Awake stages of a few minutes into
    ///   each night; 60 minutes is generous enough to absorb those while
    ///   still separating genuinely distinct naps from the main night.
    /// - parameter calendar: calendar used for the window math. Tests inject
    ///   a fixed-timezone calendar for determinism.
    /// - returns: total asleep hours from all sessions that ended in
    ///   `[dayStart, dayStart + 24h)`, with overlaps merged and the result
    ///   clipped to the safety window. Always `>= 0`.
    static func attributedHours(
        intervals: [SleepInterval],
        dayStart: Date,
        windowHoursBefore: Int = 6,
        windowHoursAfter: Int = 18,
        sessionGapToleranceMinutes: Int = 60,
        calendar: Calendar = .current
    ) -> Double {
        guard
            let windowStart = calendar.date(byAdding: .hour, value: -windowHoursBefore, to: dayStart),
            let windowEnd = calendar.date(byAdding: .hour, value: windowHoursAfter, to: dayStart),
            let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart)
        else {
            return 0
        }

        let sessions = groupIntoSessions(
            intervals,
            gapTolerance: TimeInterval(sessionGapToleranceMinutes * 60)
        )

        var totalSeconds: TimeInterval = 0
        for session in sessions {
            // Wake-day attribution: the whole session counts toward the day in which it ENDED.
            // This is what lets pre-midnight sub-samples contribute to today's total.
            guard session.end >= dayStart, session.end < dayEnd else { continue }

            // Within a qualifying session, sum the *union* of asleep sub-samples,
            // clipped to the safety window. The union excludes the brief Awake
            // gaps Apple Watch interleaves inside a session (those aren't passed
            // to us — caller filters out `.awake`), so the total matches
            // Apple Health's "Time Asleep" (which also excludes Awake).
            for interval in mergeOverlapping(session.intervals) {
                let clippedStart = max(interval.start, windowStart)
                let clippedEnd = min(interval.end, windowEnd)
                guard clippedEnd > clippedStart else { continue }
                totalSeconds += clippedEnd.timeIntervalSince(clippedStart)
            }
        }

        return max(0, totalSeconds / 3600.0)
    }

    // MARK: - Sessionization

    /// One logical sleep session — a chain of asleep intervals separated by
    /// gaps no longer than `gapTolerance`.
    struct Session: Equatable {
        var start: Date
        var end: Date
        var intervals: [SleepInterval]
    }

    /// Group sorted asleep intervals into sessions. Adjacent intervals whose
    /// gap is `<= gapTolerance` belong to the same session.
    static func groupIntoSessions(
        _ intervals: [SleepInterval],
        gapTolerance: TimeInterval
    ) -> [Session] {
        let sorted = intervals.sorted { $0.start < $1.start }
        var sessions: [Session] = []
        for interval in sorted {
            if let lastIndex = sessions.indices.last,
               interval.start.timeIntervalSince(sessions[lastIndex].end) <= gapTolerance {
                sessions[lastIndex].end = max(sessions[lastIndex].end, interval.end)
                sessions[lastIndex].intervals.append(interval)
            } else {
                sessions.append(Session(start: interval.start, end: interval.end, intervals: [interval]))
            }
        }
        return sessions
    }

    // MARK: - Overlap merging

    /// Merge overlapping or touching intervals into the union of their time ranges.
    /// Pure and exposed for unit tests.
    static func mergeOverlapping(_ intervals: [SleepInterval]) -> [SleepInterval] {
        guard intervals.count > 1 else { return intervals }
        let sorted = intervals.sorted { $0.start < $1.start }
        var merged: [SleepInterval] = []
        merged.reserveCapacity(sorted.count)
        for interval in sorted {
            if var last = merged.last, interval.start <= last.end {
                last.end = max(last.end, interval.end)
                merged[merged.count - 1] = last
            } else {
                merged.append(interval)
            }
        }
        return merged
    }
}
