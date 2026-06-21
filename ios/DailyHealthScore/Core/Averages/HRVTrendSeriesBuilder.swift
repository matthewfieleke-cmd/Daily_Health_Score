import Foundation

/// One day on the HRV chart: the actual nightly value (if any), the rolling
/// average ending that day, and the personalized corridor bounds as of that day.
/// Bounds are nil until enough baseline history exists for the date.
struct HRVTrendPoint: Identifiable, Equatable {
    var id: String { dateKey }
    var dateKey: String
    var date: Date
    var rawMs: Double?
    var trendMs: Double?
    var lowerMs: Double?
    var upperMs: Double?
}

struct HRVTrendSeries: Equatable {
    var points: [HRVTrendPoint]
    /// Current baseline mean (corridor center) for the dashed reference line.
    var baselineMeanMs: Double?
    var hasCorridor: Bool {
        points.contains { $0.lowerMs != nil && $0.upperMs != nil }
    }
}

/// Builds a time-varying corridor + trend series for `HRVGraphView`. For each
/// plotted date it recomputes the trailing baseline/acute stats so the band
/// evolves with the user's history. O(range × window); ranges are ≤ 90 days.
enum HRVTrendSeriesBuilder {
    static func build(
        records: [DailyRecord],
        todayKey: String,
        days: Int,
        sensitivity: HRVSensitivity
    ) -> HRVTrendSeries {
        guard let anchorDate = DateHelpers.date(from: todayKey) else {
            return HRVTrendSeries(points: [], baselineMeanMs: nil)
        }

        let byDate = HRVBaselineAnalyzer.valuesByDate(records)
        let windowKeys = DateHelpers.rollingDateKeys(days: days, endingOn: anchorDate)
        let k = sensitivity.multiplier

        let points: [HRVTrendPoint] = windowKeys.compactMap { key in
            guard let date = DateHelpers.date(from: key) else { return nil }

            let acute = HRVBaselineAnalyzer.acuteValues(byDate: byDate, anchorKey: key)
            let trendMs = acute.count >= HRVBaselineAnalyzer.minAcuteNights
                ? HRVBaselineAnalyzer.mean(acute)
                : nil

            let baseline = HRVBaselineAnalyzer.baselineValues(byDate: byDate, anchorKey: key)
            var lowerMs: Double?
            var upperMs: Double?
            if baseline.count >= HRVBaselineAnalyzer.minBaselineNights,
               let baselineMean = HRVBaselineAnalyzer.mean(baseline),
               let baselineSD = HRVBaselineAnalyzer.sampleStandardDeviation(baseline) {
                lowerMs = baselineMean - baselineSD * k
                upperMs = baselineMean + baselineSD * k
            }

            return HRVTrendPoint(
                dateKey: key,
                date: date,
                rawMs: byDate[key],
                trendMs: trendMs,
                lowerMs: lowerMs,
                upperMs: upperMs
            )
        }

        let baselineMeanMs: Double? = {
            let baseline = HRVBaselineAnalyzer.baselineValues(byDate: byDate, anchorKey: todayKey)
            guard baseline.count >= HRVBaselineAnalyzer.minBaselineNights else { return nil }
            return HRVBaselineAnalyzer.mean(baseline)
        }()

        return HRVTrendSeries(points: points, baselineMeanMs: baselineMeanMs)
    }
}
