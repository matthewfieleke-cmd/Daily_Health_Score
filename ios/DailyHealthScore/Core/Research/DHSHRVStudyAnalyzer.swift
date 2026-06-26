import Foundation

enum DHSHRVStudyAnalyzer {
    private struct WindowComputation {
        var todayKey: String
        var dhsStartDate: String
        var dhsEndDate: String
        var hrvStartDate: String
        var hrvEndDate: String
        var dailyPairs: [DHSHRVDailyPair]
        var weeklyPoints: [DHSHRVWeeklyPoint]
        var zScorePoints: [DHSHRVZScorePoint]
        var scatterPoints: [DHSHRVScatterPoint]
        var correlation: DHSHRVCorrelationResult
    }

    static func analyze(
        records: [DailyRecord],
        todayKey: String = DateHelpers.localDateKey()
    ) -> DHSHRVStudyResult? {
        guard let current = computeWindow(records: records, todayKey: todayKey) else {
            return nil
        }

        return DHSHRVStudyResult(
            todayKey: current.todayKey,
            dhsStartDate: current.dhsStartDate,
            dhsEndDate: current.dhsEndDate,
            hrvStartDate: current.hrvStartDate,
            hrvEndDate: current.hrvEndDate,
            dailyPairs: current.dailyPairs,
            weeklyPoints: current.weeklyPoints,
            zScorePoints: current.zScorePoints,
            scatterPoints: current.scatterPoints,
            correlation: current.correlation,
            alignmentPoints: alignmentPoints(records: records, endingOnTodayKey: todayKey)
        )
    }

    private static func computeWindow(records: [DailyRecord], todayKey: String) -> WindowComputation? {
        guard let yesterdayKey = DateHelpers.addDays(to: todayKey, days: -1),
              let yesterday = DateHelpers.date(from: yesterdayKey) else {
            return nil
        }

        let dhsKeys = DateHelpers.rollingDateKeys(
            days: DHSHRVStudyResult.studyWindowDays,
            endingOn: yesterday
        )
        guard dhsKeys.count == DHSHRVStudyResult.studyWindowDays,
              let dhsStart = dhsKeys.first,
              let dhsEnd = dhsKeys.last,
              let hrvStart = DateHelpers.addDays(to: dhsStart, days: 1),
              let hrvEnd = DateHelpers.addDays(to: dhsEnd, days: 1) else {
            return nil
        }

        let byDate = Dictionary(uniqueKeysWithValues: records.map { ($0.date, $0) })
        let dailyPairs = dhsKeys.compactMap { dhsKey -> DHSHRVDailyPair? in
            guard let hrvKey = DateHelpers.addDays(to: dhsKey, days: 1) else { return nil }
            return DHSHRVDailyPair(
                dhsDate: dhsKey,
                hrvDate: hrvKey,
                dhsScore: byDate[dhsKey]?.totalScore,
                followingNightHRV: byDate[hrvKey]?.sleepHrvSDNNMs
            )
        }

        let weeklyPoints = weeklyPoints(from: dailyPairs)
        let scatterPoints = weeklyPoints.compactMap { point -> DHSHRVScatterPoint? in
            guard let averageDHS = point.averageDHS,
                  let averageHRV = point.averageHRV else {
                return nil
            }
            return DHSHRVScatterPoint(
                weekIndex: point.weekIndex,
                averageDHS: averageDHS,
                averageHRV: averageHRV
            )
        }

        return WindowComputation(
            todayKey: todayKey,
            dhsStartDate: dhsStart,
            dhsEndDate: dhsEnd,
            hrvStartDate: hrvStart,
            hrvEndDate: hrvEnd,
            dailyPairs: dailyPairs,
            weeklyPoints: weeklyPoints,
            zScorePoints: zScorePoints(from: weeklyPoints),
            scatterPoints: scatterPoints,
            correlation: correlation(for: scatterPoints)
        )
    }

    private static func alignmentPoints(records: [DailyRecord], endingOnTodayKey todayKey: String) -> [DHSHRVAlignmentPoint] {
        (0 ..< DHSHRVStudyResult.alignmentWindowCount).reversed().compactMap { offset in
            guard let windowTodayKey = DateHelpers.addDays(to: todayKey, days: -offset),
                  let window = computeWindow(records: records, todayKey: windowTodayKey) else {
                return nil
            }
            return DHSHRVAlignmentPoint(
                index: DHSHRVStudyResult.alignmentWindowCount - offset,
                windowStartDate: window.dhsStartDate,
                windowEndDate: window.dhsEndDate,
                spearman: window.correlation.spearman,
                pearson: window.correlation.pearson,
                pairedWeeks: window.correlation.pairedWeeks
            )
        }
    }

    private static func weeklyPoints(from dailyPairs: [DHSHRVDailyPair]) -> [DHSHRVWeeklyPoint] {
        stride(from: 0, to: dailyPairs.count, by: DHSHRVStudyResult.blockDays).enumerated().compactMap { index, start in
            let block = Array(dailyPairs[start ..< min(start + DHSHRVStudyResult.blockDays, dailyPairs.count)])
            guard block.count == DHSHRVStudyResult.blockDays,
                  let first = block.first,
                  let last = block.last else {
                return nil
            }

            let dhsValues = block.compactMap(\.dhsScore)
            let hrvValues = block.compactMap(\.followingNightHRV)

            return DHSHRVWeeklyPoint(
                weekIndex: index + 1,
                dhsStartDate: first.dhsDate,
                dhsEndDate: last.dhsDate,
                hrvStartDate: first.hrvDate,
                hrvEndDate: last.hrvDate,
                averageDHS: mean(dhsValues),
                averageHRV: mean(hrvValues),
                dhsValueCount: dhsValues.count,
                hrvValueCount: hrvValues.count
            )
        }
    }

    private static func zScorePoints(from weeklyPoints: [DHSHRVWeeklyPoint]) -> [DHSHRVZScorePoint] {
        let dhsValues = weeklyPoints.compactMap(\.averageDHS)
        let hrvValues = weeklyPoints.compactMap(\.averageHRV)
        let dhsMean = mean(dhsValues)
        let hrvMean = mean(hrvValues)
        let dhsSD = sampleStandardDeviation(dhsValues)
        let hrvSD = sampleStandardDeviation(hrvValues)

        var points: [DHSHRVZScorePoint] = []
        for point in weeklyPoints {
            if let averageDHS = point.averageDHS, let dhsMean {
                points.append(
                    DHSHRVZScorePoint(
                        weekIndex: point.weekIndex,
                        series: "DHS",
                        zScore: zScore(value: averageDHS, mean: dhsMean, standardDeviation: dhsSD)
                    )
                )
            }
            if let averageHRV = point.averageHRV, let hrvMean {
                points.append(
                    DHSHRVZScorePoint(
                        weekIndex: point.weekIndex,
                        series: "HRV",
                        zScore: zScore(value: averageHRV, mean: hrvMean, standardDeviation: hrvSD)
                    )
                )
            }
        }
        return points
    }

    private static func correlation(for points: [DHSHRVScatterPoint]) -> DHSHRVCorrelationResult {
        let x = points.map(\.averageDHS)
        let y = points.map(\.averageHRV)
        return DHSHRVCorrelationResult(
            spearman: spearman(x: x, y: y),
            pearson: pearson(x: x, y: y),
            pairedWeeks: points.count
        )
    }

    private static func mean(_ values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }

    private static func zScore(value: Double, mean: Double, standardDeviation: Double?) -> Double {
        guard let standardDeviation, standardDeviation > 0 else { return 0 }
        return (value - mean) / standardDeviation
    }

    private static func sampleStandardDeviation(_ values: [Double]) -> Double? {
        guard values.count >= 2, let mean = mean(values) else { return nil }
        let sumSquares = values.reduce(0) { $0 + pow($1 - mean, 2) }
        return sqrt(sumSquares / Double(values.count - 1))
    }

    private static func pearson(x: [Double], y: [Double]) -> Double? {
        guard x.count == y.count, x.count >= 2,
              let meanX = mean(x),
              let meanY = mean(y) else {
            return nil
        }

        let numerator = zip(x, y).reduce(0) { partial, pair in
            partial + (pair.0 - meanX) * (pair.1 - meanY)
        }
        let denominatorX = x.reduce(0) { $0 + pow($1 - meanX, 2) }
        let denominatorY = y.reduce(0) { $0 + pow($1 - meanY, 2) }
        let denominator = sqrt(denominatorX * denominatorY)
        guard denominator > 0 else { return nil }
        return numerator / denominator
    }

    private static func spearman(x: [Double], y: [Double]) -> Double? {
        guard x.count == y.count, x.count >= 2 else { return nil }
        return pearson(x: ranks(for: x), y: ranks(for: y))
    }

    private static func ranks(for values: [Double]) -> [Double] {
        let sorted = values.enumerated().sorted { lhs, rhs in
            if lhs.element == rhs.element { return lhs.offset < rhs.offset }
            return lhs.element < rhs.element
        }
        var ranks = Array(repeating: 0.0, count: values.count)
        var index = 0

        while index < sorted.count {
            var end = index
            while end + 1 < sorted.count, sorted[end + 1].element == sorted[index].element {
                end += 1
            }
            let averageRank = (Double(index + 1) + Double(end + 1)) / 2.0
            for tiedIndex in index ... end {
                ranks[sorted[tiedIndex].offset] = averageRank
            }
            index = end + 1
        }

        return ranks
    }
}
