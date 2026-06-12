import Foundation

struct HRVChartPoint: Identifiable, Equatable {
    var id: String { dateKey }
    var dateKey: String
    var date: Date
    var valueMs: Double
}

struct HRVChartSeries: Equatable {
    var points: [HRVChartPoint]
    var averageMs: Double?
}

enum HRVChartSeriesBuilder {
    static func build(records: [DailyRecord], todayKey: String, days: Int) -> HRVChartSeries {
        guard let anchorDate = DateHelpers.date(from: todayKey) else {
            return HRVChartSeries(points: [], averageMs: nil)
        }

        let windowKeys = DateHelpers.rollingDateKeys(days: days, endingOn: anchorDate)
        let byDate = Dictionary(uniqueKeysWithValues: records.map { ($0.date, $0) })

        let points: [HRVChartPoint] = windowKeys.compactMap { key in
            guard let valueMs = byDate[key]?.sleepHrvSDNNMs,
                  let date = DateHelpers.date(from: key) else {
                return nil
            }
            return HRVChartPoint(dateKey: key, date: date, valueMs: valueMs)
        }

        let averageMs: Double? = points.isEmpty
            ? nil
            : points.map(\.valueMs).reduce(0, +) / Double(points.count)

        return HRVChartSeries(points: points, averageMs: averageMs)
    }
}
