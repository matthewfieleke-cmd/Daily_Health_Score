import Foundation

enum HRVTrend: Equatable {
    case up
    case down
    case steady
    case needsMoreHistory
}

struct HRVRollingSummary: Equatable {
    var averageMs: Double?
    var nightsWithData: Int
    var nightsInWindow: Int
    var trend: HRVTrend
}

enum HRVRollingCalculator {
    static let windowDays = 7
    static let trendThresholdMs = 3.0

    static func compute(records: [DailyRecord], todayKey: String) -> HRVRollingSummary {
        let currentKeys = rollingWindowKeys(endingOn: todayKey, dayCount: windowDays)
        let previousKeys = previousWindowKeys(endingBefore: todayKey, dayCount: windowDays)

        let byDate = Dictionary(uniqueKeysWithValues: records.map { ($0.date, $0) })
        let currentValues = currentKeys.compactMap { byDate[$0]?.sleepHrvSDNNMs }
        let previousValues = previousKeys.compactMap { byDate[$0]?.sleepHrvSDNNMs }

        let averageMs: Double? = currentValues.isEmpty
            ? nil
            : currentValues.reduce(0, +) / Double(currentValues.count)

        let trend: HRVTrend
        if currentValues.count < windowDays || previousValues.count < windowDays {
            trend = .needsMoreHistory
        } else if let currentAverage = average(of: currentValues),
                  let previousAverage = average(of: previousValues) {
            let delta = currentAverage - previousAverage
            if delta > trendThresholdMs {
                trend = .up
            } else if delta < -trendThresholdMs {
                trend = .down
            } else {
                trend = .steady
            }
        } else {
            trend = .needsMoreHistory
        }

        return HRVRollingSummary(
            averageMs: averageMs,
            nightsWithData: currentValues.count,
            nightsInWindow: windowDays,
            trend: trend
        )
    }

    private static func rollingWindowKeys(endingOn anchorKey: String, dayCount: Int) -> [String] {
        guard let anchorDate = DateHelpers.date(from: anchorKey) else { return [] }
        return DateHelpers.rollingDateKeys(days: dayCount, endingOn: anchorDate)
    }

    private static func previousWindowKeys(endingBefore anchorKey: String, dayCount: Int) -> [String] {
        guard let dayBeforeAnchor = DateHelpers.addDays(to: anchorKey, days: -dayCount),
              let anchorDate = DateHelpers.date(from: dayBeforeAnchor) else {
            return []
        }
        return DateHelpers.rollingDateKeys(days: dayCount, endingOn: anchorDate)
    }

    private static func average(of values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }

}
