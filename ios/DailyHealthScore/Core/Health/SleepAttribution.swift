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
/// Two important behaviors that make our totals line up with Apple Health's
/// "Time Asleep" summary:
///
/// 1. **Wake-day attribution.** A sleep interval counts toward day `D` when
///    its `end` falls in `[startOfDay(D), startOfDay(D+1))`. This matches the
///    "wake-day" convention used by Apple Health's Sleep summary.
/// 2. **Interval merging.** Overlapping intervals are merged before summing.
///    Without this, multiple HealthKit sources logging the same sleep window
///    (Apple Watch + AutoSleep + iPhone, for example) would be double-counted.
///    Apple Health's Summary view also de-duplicates across sources; merging
///    matches that behavior.
enum SleepAttribution {
    /// Hours of asleep time attributed to the wake day starting at `dayStart`.
    ///
    /// - parameter intervals: every "asleep" sample's `[start, end)`, from any
    ///   number of HealthKit sources. Caller filters to asleep category values.
    /// - parameter dayStart: midnight (local) of the wake day to attribute to.
    /// - parameter windowHoursBefore: how many hours before `dayStart` are
    ///   eligible to be included (default 6 → 6:00 PM the prior day).
    /// - parameter windowHoursAfter: how many hours after `dayStart` are
    ///   eligible to be included (default 12 → noon of the wake day).
    /// - parameter calendar: calendar used for the window math. Tests inject
    ///   a fixed-timezone calendar for determinism.
    /// - returns: total asleep hours, after clipping to the window and merging
    ///   overlapping intervals. Always `>= 0`.
    static func attributedHours(
        intervals: [SleepInterval],
        dayStart: Date,
        windowHoursBefore: Int = 6,
        windowHoursAfter: Int = 12,
        calendar: Calendar = .current
    ) -> Double {
        guard
            let windowStart = calendar.date(byAdding: .hour, value: -windowHoursBefore, to: dayStart),
            let windowEnd = calendar.date(byAdding: .hour, value: windowHoursAfter, to: dayStart),
            let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart)
        else {
            return 0
        }

        // 1. Wake-day attribution: keep only intervals whose end falls in [dayStart, dayEnd).
        //    Then clip each interval to the broader window so a sleep period that
        //    started before windowStart or ended after windowEnd is still capped sensibly.
        let attributed: [SleepInterval] = intervals.compactMap { interval in
            guard interval.end >= dayStart, interval.end < dayEnd else { return nil }
            let clippedStart = max(interval.start, windowStart)
            let clippedEnd = min(interval.end, windowEnd)
            guard clippedEnd > clippedStart else { return nil }
            return SleepInterval(start: clippedStart, end: clippedEnd)
        }

        // 2. Merge overlaps so multiple HealthKit sources don't double-count.
        let merged = mergeOverlapping(attributed)

        let totalSeconds = merged.reduce(0.0) { acc, interval in
            acc + interval.end.timeIntervalSince(interval.start)
        }
        return max(0, totalSeconds / 3600.0)
    }

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
