import Foundation

/// A single SDNN HRV reading from HealthKit.
struct HRVSample: Equatable {
    var timestamp: Date
    var sdnnMilliseconds: Double
}

/// Averages HRV samples that fall inside wake-day attributed sleep intervals.
enum SleepHRVAttribution {
    static func averageSDNNMs(
        samples: [HRVSample],
        asleepIntervals: [SleepInterval],
        dayStart: Date,
        calendar: Calendar = .current
    ) -> Double? {
        let sleepIntervals = SleepAttribution.attributedSleepIntervals(
            intervals: asleepIntervals,
            dayStart: dayStart,
            calendar: calendar
        )
        guard !sleepIntervals.isEmpty else { return nil }

        let values = samples.compactMap { sample -> Double? in
            let isDuringSleep = sleepIntervals.contains { interval in
                interval.start <= sample.timestamp && sample.timestamp < interval.end
            }
            guard isDuringSleep else { return nil }
            return sample.sdnnMilliseconds
        }
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }
}
