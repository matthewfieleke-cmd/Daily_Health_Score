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
