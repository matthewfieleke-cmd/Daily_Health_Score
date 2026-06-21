import XCTest
@testable import DailyHealthScore

final class HRVBaselineAnalyzerTests: XCTestCase {
    private let anchor = "2026-06-30"

    private func record(date: String, hrv: Double?) -> DailyRecord {
        DailyRecord(
            date: date,
            sleepHours: 7,
            fiberGrams: 30,
            exerciseMinutes: 30,
            sleepHrvSDNNMs: hrv,
            sleepGoal: .sevenHalf,
            fiberGoal: .forty,
            sleepScore: 3,
            fiberScore: 3,
            exerciseScore: 2,
            totalScore: 8,
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
        guard let date = DateHelpers.date(from: key) else { return [] }
        return DateHelpers.rollingDateKeys(days: days, endingOn: date)
    }

    private var acuteKeys: [String] { keys(endingOn: anchor, days: 7) }

    private var baselineKeys: [String] {
        guard let end = DateHelpers.addDays(to: anchor, days: -7) else { return [] }
        return keys(endingOn: end, days: 28)
    }

    /// Baseline of 28 nights alternating 45/55 (mean 50, sample SD ≈ 5.09),
    /// plus 7 acute nights at a fixed value.
    private func standardRecords(acute: Double) -> [DailyRecord] {
        var records: [DailyRecord] = []
        for (index, key) in baselineKeys.enumerated() {
            records.append(record(date: key, hrv: index.isMultiple(of: 2) ? 45 : 55))
        }
        for key in acuteKeys {
            records.append(record(date: key, hrv: acute))
        }
        return records
    }

    // MARK: - Cold start

    func test_coldStart_tooFewBaselineNights_buildsBaseline() {
        let recent = keys(endingOn: anchor, days: 5).map { record(date: $0, hrv: 50) }
        let state = HRVBaselineAnalyzer.analyze(records: recent, todayKey: anchor, sensitivity: .balanced)
        XCTAssertEqual(state, .buildingBaseline(validNights: 5))
    }

    func test_coldStart_thirteenBaselineNights_stillBuilding() {
        var records: [DailyRecord] = []
        for key in baselineKeys.prefix(13) { records.append(record(date: key, hrv: 50)) }
        for key in acuteKeys { records.append(record(date: key, hrv: 50)) }
        let state = HRVBaselineAnalyzer.analyze(records: records, todayKey: anchor, sensitivity: .balanced)
        XCTAssertEqual(state, .buildingBaseline(validNights: 13 + acuteKeys.count))
    }

    // MARK: - Classification

    func test_withinRange_whenTrendNearBaselineMean() {
        let state = HRVBaselineAnalyzer.analyze(records: standardRecords(acute: 50), todayKey: anchor, sensitivity: .balanced)
        guard case .ready(let result) = state else { return XCTFail("expected ready") }
        XCTAssertEqual(result.status, .withinRange)
        XCTAssertEqual(result.baselineMean, 50, accuracy: 0.001)
        XCTAssertEqual(result.trendMean, 50, accuracy: 0.001)
        XCTAssertFalse(result.isHighVariability)
    }

    func test_belowRange_whenTrendDropsBelowCorridor() {
        let state = HRVBaselineAnalyzer.analyze(records: standardRecords(acute: 40), todayKey: anchor, sensitivity: .balanced)
        guard case .ready(let result) = state else { return XCTFail("expected ready") }
        XCTAssertEqual(result.status, .belowRange)
    }

    func test_aboveRange_whenTrendExceedsCorridor() {
        let state = HRVBaselineAnalyzer.analyze(records: standardRecords(acute: 62), todayKey: anchor, sensitivity: .balanced)
        guard case .ready(let result) = state else { return XCTFail("expected ready") }
        XCTAssertEqual(result.status, .aboveRange)
    }

    func test_sensitivityWidensCorridor() {
        // Trend of 43 sits below the Balanced corridor but inside the wider Low corridor.
        let balanced = HRVBaselineAnalyzer.analyze(records: standardRecords(acute: 43), todayKey: anchor, sensitivity: .balanced)
        let low = HRVBaselineAnalyzer.analyze(records: standardRecords(acute: 43), todayKey: anchor, sensitivity: .low)
        guard case .ready(let balancedResult) = balanced,
              case .ready(let lowResult) = low else { return XCTFail("expected ready") }
        XCTAssertEqual(balancedResult.status, .belowRange)
        XCTAssertEqual(lowResult.status, .withinRange)
        XCTAssertLessThan(lowResult.lowerBound, balancedResult.lowerBound)
    }

    // MARK: - Statistics

    func test_coefficientOfVariation() {
        let state = HRVBaselineAnalyzer.analyze(records: standardRecords(acute: 50), todayKey: anchor, sensitivity: .balanced)
        guard case .ready(let result) = state else { return XCTFail("expected ready") }
        // SD ≈ 5.09 on a mean of 50 → CV ≈ 10.2%.
        XCTAssertEqual(result.cvPercent, 10.18, accuracy: 0.3)
    }

    func test_highVariability_whenRecentWeekFarMoreVariableThanBaseline() {
        var records: [DailyRecord] = []
        for (index, key) in baselineKeys.enumerated() {
            records.append(record(date: key, hrv: index.isMultiple(of: 2) ? 49 : 51))
        }
        let volatile: [Double] = [40, 60, 40, 60, 50, 50, 50]
        for (index, key) in acuteKeys.enumerated() {
            records.append(record(date: key, hrv: volatile[index % volatile.count]))
        }
        let state = HRVBaselineAnalyzer.analyze(records: records, todayKey: anchor, sensitivity: .balanced)
        guard case .ready(let result) = state else { return XCTFail("expected ready") }
        XCTAssertTrue(result.isHighVariability)
    }

    // MARK: - Window separation & sparse data

    func test_baselineAndAcuteWindowsDoNotOverlap() {
        var records: [DailyRecord] = []
        for key in baselineKeys { records.append(record(date: key, hrv: 60)) }
        for key in acuteKeys { records.append(record(date: key, hrv: 40)) }
        let state = HRVBaselineAnalyzer.analyze(records: records, todayKey: anchor, sensitivity: .balanced)
        guard case .ready(let result) = state else { return XCTFail("expected ready") }
        // Pooling would blur these; separation keeps baseline at 60 and trend at 40.
        XCTAssertEqual(result.baselineMean, 60, accuracy: 0.001)
        XCTAssertEqual(result.trendMean, 40, accuracy: 0.001)
        XCTAssertEqual(result.status, .belowRange)
    }

    func test_sparseNights_ignoresMissingData_atMinimumThreshold() {
        var records: [DailyRecord] = []
        for key in baselineKeys.prefix(14) { records.append(record(date: key, hrv: 50)) }
        for key in acuteKeys.prefix(4) { records.append(record(date: key, hrv: 50)) }
        let state = HRVBaselineAnalyzer.analyze(records: records, todayKey: anchor, sensitivity: .balanced)
        guard case .ready(let result) = state else { return XCTFail("expected ready at 14/4 nights") }
        XCTAssertEqual(result.status, .withinRange)
    }
}
