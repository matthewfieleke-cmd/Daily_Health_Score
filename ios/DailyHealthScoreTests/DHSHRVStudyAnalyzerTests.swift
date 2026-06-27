import SwiftData
import XCTest
@testable import DailyHealthScore

final class DHSHRVStudyAnalyzerTests: XCTestCase {
    private let settings = UserSettings(sleepGoal: .sevenHalf, fiberGoal: .forty)

    private func record(date: String, score: Double, hrv: Double? = nil) -> DailyRecord {
        DailyRecord(
            date: date,
            sleepHours: 7.5,
            fiberGrams: 40,
            exerciseMinutes: 30,
            sleepHrvSDNNMs: hrv,
            sleepGoal: settings.sleepGoal,
            fiberGoal: settings.fiberGoal,
            sleepScore: 4,
            fiberScore: 4,
            exerciseScore: 2,
            totalScore: score,
            sleepPercent: 1,
            fiberPercent: 1,
            exercisePercent: 1,
            primaryFocus: .maintain,
            suggestion: "",
            createdAt: Date(timeIntervalSince1970: 0),
            updatedAt: Date(timeIntervalSince1970: 0)
        )
    }

    private func keys(endingOn key: String, days: Int) -> [String] {
        DateHelpers.date(from: key).map { DateHelpers.rollingDateKeys(days: days, endingOn: $0) } ?? []
    }

    private func records(scores: [String: Double], hrvs: [String: Double]) -> [DailyRecord] {
        let allKeys = Set(scores.keys).union(hrvs.keys)
        return allKeys.map { key in
            record(date: key, score: scores[key] ?? 0, hrv: hrvs[key])
        }
    }

    func test_latestNinetyOneCompleteDHSDays_endYesterday() {
        let result = DHSHRVStudyAnalyzer.analyze(records: [], todayKey: "2026-06-25")

        XCTAssertEqual(result?.dhsStartDate, "2026-03-26")
        XCTAssertEqual(result?.dhsEndDate, "2026-06-24")
        XCTAssertEqual(result?.hrvStartDate, "2026-03-27")
        XCTAssertEqual(result?.hrvEndDate, "2026-06-25")
        XCTAssertEqual(result?.dailyPairs.count, 91)
        XCTAssertEqual(result?.weeklyPoints.count, 13)
    }

    func test_dailyPair_usesDHSDateAndFollowingHRVDate() {
        let records = records(
            scores: ["2026-03-26": 8, "2026-03-27": 4],
            hrvs: ["2026-03-27": 52]
        )

        let result = DHSHRVStudyAnalyzer.analyze(records: records, todayKey: "2026-06-25")
        let firstPair = result?.dailyPairs.first

        XCTAssertEqual(firstPair?.dhsDate, "2026-03-26")
        XCTAssertEqual(firstPair?.hrvDate, "2026-03-27")
        XCTAssertEqual(firstPair?.dhsScore, 8)
        XCTAssertEqual(firstPair?.followingNightHRV, 52)
    }

    func test_weeklyBlocks_averageAvailableValuesOnly() {
        var scores: [String: Double] = [:]
        var hrvs: [String: Double] = [:]
        let dhsKeys = keys(endingOn: "2026-06-24", days: 91)
        for (index, key) in dhsKeys.prefix(7).enumerated() {
            scores[key] = Double(index + 1)
            if let hrvKey = DateHelpers.addDays(to: key, days: 1), index < 3 {
                hrvs[hrvKey] = Double(50 + index)
            }
        }

        let weekOne = DHSHRVStudyAnalyzer.analyze(
            records: records(scores: scores, hrvs: hrvs),
            todayKey: "2026-06-25"
        )?.weeklyPoints.first

        XCTAssertEqual(weekOne?.averageDHS ?? 0, 4, accuracy: 0.001)
        XCTAssertEqual(weekOne?.dhsValueCount, 7)
        XCTAssertEqual(weekOne?.averageHRV ?? 0, 51, accuracy: 0.001)
        XCTAssertEqual(weekOne?.hrvValueCount, 3)
        XCTAssertEqual(weekOne?.dhsCompleteness, .solid)
        XCTAssertEqual(weekOne?.hrvCompleteness, .sparse)
    }

    func test_correlationUsesThirteenWeeklyPoints() {
        var scores: [String: Double] = [:]
        var hrvs: [String: Double] = [:]
        let dhsKeys = keys(endingOn: "2026-06-24", days: 91)
        for (index, key) in dhsKeys.enumerated() {
            let week = index / 7
            scores[key] = Double(week + 1)
            if let hrvKey = DateHelpers.addDays(to: key, days: 1) {
                hrvs[hrvKey] = Double(40 + week)
            }
        }

        let result = DHSHRVStudyAnalyzer.analyze(
            records: records(scores: scores, hrvs: hrvs),
            todayKey: "2026-06-25"
        )

        XCTAssertEqual(result?.scatterPoints.count, 13)
        XCTAssertEqual(result?.correlation.pairedWeeks, 13)
        XCTAssertEqual(result?.correlation.spearman ?? 0, 1, accuracy: 0.001)
        XCTAssertEqual(result?.correlation.pearson ?? 0, 1, accuracy: 0.001)
        XCTAssertEqual(result?.correlation.displayLabel, "Strong positive")
    }

    func test_zScoresAreGeneratedForBothSeries() {
        var scores: [String: Double] = [:]
        var hrvs: [String: Double] = [:]
        let dhsKeys = keys(endingOn: "2026-06-24", days: 91)
        for (index, key) in dhsKeys.enumerated() {
            let week = index / 7
            scores[key] = Double(week + 1)
            if let hrvKey = DateHelpers.addDays(to: key, days: 1) {
                hrvs[hrvKey] = Double(100 - week)
            }
        }

        let result = DHSHRVStudyAnalyzer.analyze(
            records: records(scores: scores, hrvs: hrvs),
            todayKey: "2026-06-25"
        )

        XCTAssertEqual(result?.zScorePoints.count, 26)
        XCTAssertEqual(Set(result?.zScorePoints.map(\.series) ?? []), ["DHS", "HRV"])
    }

    func test_alignmentPoints_includeLastThirtyMovingWindows() {
        var scores: [String: Double] = [:]
        var hrvs: [String: Double] = [:]
        let dhsKeys = keys(endingOn: "2026-06-24", days: 120)
        for (index, key) in dhsKeys.enumerated() {
            let week = index / 7
            scores[key] = Double(week + 1)
            if let hrvKey = DateHelpers.addDays(to: key, days: 1) {
                hrvs[hrvKey] = Double(40 + week)
            }
        }

        let result = DHSHRVStudyAnalyzer.analyze(
            records: records(scores: scores, hrvs: hrvs),
            todayKey: "2026-06-25"
        )

        XCTAssertEqual(result?.alignmentPoints.count, 30)
        XCTAssertEqual(result?.alignmentPoints.first?.index, 1)
        XCTAssertEqual(result?.alignmentPoints.last?.index, 30)
        XCTAssertEqual(result?.alignmentPoints.last?.windowEndDate, "2026-06-24")
        XCTAssertEqual(result?.alignmentPoints.last?.spearman ?? 0, 1, accuracy: 0.001)
    }

    func test_correlationChange_comparesCurrentToPreviousWindow() {
        let change = DHSHRVCorrelationChange(current: 0.34, previous: 0.05)

        XCTAssertEqual(change.delta ?? 0, 0.29, accuracy: 0.001)
        XCTAssertEqual(change.formattedDelta, "+0.29")
        XCTAssertEqual(change.directionText, "More positive than the previous window")
    }

    func test_confidenceInterval_bracketsValueAndWidensForSmallN() throws {
        let interval = try XCTUnwrap(DHSHRVStatistics.confidenceInterval(spearman: 0.5, n: 13))

        XCTAssertLessThan(interval.lower, 0.5)
        XCTAssertGreaterThan(interval.upper, 0.5)
        XCTAssertLessThan(interval.lower, 0, "With only 13 points a moderate value should still allow a negative lower bound")
        XCTAssertNil(DHSHRVStatistics.confidenceInterval(spearman: 0.5, n: 4))
        XCTAssertNil(DHSHRVStatistics.confidenceInterval(spearman: 1.0, n: 13))
    }

    func test_statisticsLabel_mapsMagnitudeAndDirection() {
        XCTAssertEqual(DHSHRVStatistics.label(for: 0.0), "no")
        XCTAssertEqual(DHSHRVStatistics.label(for: 0.2), "weak positive")
        XCTAssertEqual(DHSHRVStatistics.label(for: 0.45), "moderate positive")
        XCTAssertEqual(DHSHRVStatistics.label(for: -0.8), "strong negative")
    }

    func test_scatterFit_hasPositiveSlopeWhenHRVRisesWithDHS() {
        var scores: [String: Double] = [:]
        var hrvs: [String: Double] = [:]
        let dhsKeys = keys(endingOn: "2026-06-24", days: 91)
        for (index, key) in dhsKeys.enumerated() {
            let week = index / 7
            scores[key] = Double(week + 1)
            if let hrvKey = DateHelpers.addDays(to: key, days: 1) {
                hrvs[hrvKey] = Double(40 + week)
            }
        }

        let fit = DHSHRVStudyAnalyzer.analyze(
            records: records(scores: scores, hrvs: hrvs),
            todayKey: "2026-06-25"
        )?.scatterFit

        XCTAssertNotNil(fit)
        XCTAssertGreaterThan(fit?.slope ?? 0, 0)
    }

    func test_alignmentStats_summarizeMedianRangeAndDirection() {
        var scores: [String: Double] = [:]
        var hrvs: [String: Double] = [:]
        let dhsKeys = keys(endingOn: "2026-06-24", days: 120)
        for (index, key) in dhsKeys.enumerated() {
            let week = index / 7
            scores[key] = Double(week + 1)
            if let hrvKey = DateHelpers.addDays(to: key, days: 1) {
                hrvs[hrvKey] = Double(40 + week)
            }
        }

        let result = DHSHRVStudyAnalyzer.analyze(
            records: records(scores: scores, hrvs: hrvs),
            todayKey: "2026-06-25"
        )
        let stats = result?.alignmentStats

        XCTAssertEqual(stats?.total, 30)
        XCTAssertEqual(stats?.positiveCount, 30)
        XCTAssertEqual(stats?.median ?? 0, 1, accuracy: 0.001)
        XCTAssertEqual(stats?.minValue ?? 0, 1, accuracy: 0.001)
        XCTAssertEqual(stats?.maxValue ?? 0, 1, accuracy: 0.001)
        XCTAssertEqual(stats?.direction, .steady)
    }

    func test_significanceText_isEncouragingWhenIntervalCrossesZero() {
        var scores: [String: Double] = [:]
        var hrvs: [String: Double] = [:]
        let dhsKeys = keys(endingOn: "2026-06-24", days: 91)
        // Mild positive pairing so the 91-day window produces a non-clear interval.
        for (index, key) in dhsKeys.enumerated() {
            let week = index / 7
            scores[key] = Double((week % 3) + 1)
            if let hrvKey = DateHelpers.addDays(to: key, days: 1) {
                hrvs[hrvKey] = Double(45 + (week % 2))
            }
        }

        let result = DHSHRVStudyAnalyzer.analyze(
            records: records(scores: scores, hrvs: hrvs),
            todayKey: "2026-06-25"
        )

        XCTAssertNotNil(result?.confidence)
        XCTAssertFalse(result?.significanceText.isEmpty ?? true)
    }

    @MainActor
    func test_saveManualDay_preservesExistingHRV() throws {
        let container = try ModelContainer(
            for: DailyRecordEntity.self,
            SMARTGoalEntity.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let appState = AppState(modelContext: ModelContext(container))
        appState.recordStore.save(record(date: "2026-06-24", score: 8, hrv: 61))

        appState.saveManualDay(
            date: "2026-06-24",
            metrics: DailyMetrics(sleepHours: 6, fiberGrams: 20, exerciseMinutes: 15)
        )

        XCTAssertEqual(appState.recordStore.records.first?.sleepHrvSDNNMs, 61)
    }
}
