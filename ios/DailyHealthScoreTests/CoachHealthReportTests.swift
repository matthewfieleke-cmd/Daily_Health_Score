import XCTest
@testable import DailyHealthScore

final class CoachHealthReportTests: XCTestCase {
    func test_parseKeepsRestingAndWalkingApartFromHeartRate() {
        XCTAssertEqual(CoachHealthMeasure.parseOne("resting heart rate"), .restingHeartRate)
        XCTAssertEqual(CoachHealthMeasure.parseOne("walking heart rate"), .walkingHeartRate)
        XCTAssertEqual(CoachHealthMeasure.parseOne("heart rate"), .heartRate)
        XCTAssertEqual(CoachHealthMeasure.parseOne("running speed"), .running)
        XCTAssertEqual(
            CoachHealthMeasure.parseList("heart rate, resting heart rate, blood oxygen"),
            [.heartRate, .restingHeartRate, .bloodOxygen]
        )
        XCTAssertNil(CoachHealthMeasure.parseOne("none"))
        XCTAssertNil(CoachHealthMeasure.parseOne("sleep"))
    }

    func test_heartRateStatesTheRangeAndDoesNotInventAGoal() {
        let facts = CoachHealthReport.facts(
            measures: [
                CoachHealthMeasureFacts(
                    measure: .heartRate,
                    days: [CoachHealthDayValue(dateKey: "2026-10-10", low: 52, high: 141, average: 68)]
                )
            ],
            startKey: "2026-10-10",
            endKey: "2026-10-10",
            todayKey: "2026-10-10"
        )
        XCTAssertTrue(facts.hasRecord)
        XCTAssertTrue(facts.text.contains("low 52"))
        XCTAssertTrue(facts.text.contains("high 141"))
        XCTAssertTrue(facts.text.contains("average 68 bpm"))
        XCTAssertFalse(facts.text.localizedCaseInsensitiveContains("goal"))
        XCTAssertFalse(facts.text.localizedCaseInsensitiveContains("score"))
        XCTAssertFalse(facts.text.contains("0 bpm"))
    }

    func test_missingDayIsNoRecord() {
        let facts = CoachHealthReport.facts(
            measures: [CoachHealthMeasureFacts(measure: .restingHeartRate)],
            startKey: "2026-10-10",
            endKey: "2026-10-10",
            todayKey: "2026-10-10"
        )
        XCTAssertFalse(facts.hasRecord)
        XCTAssertTrue(facts.text.contains("no record"))
        XCTAssertFalse(facts.text.contains("0 bpm"))
        XCTAssertFalse(facts.text.contains("zero"))
        XCTAssertNil(facts.chart)
    }

    func test_gapDaysAreLeftOutOfTheChart() {
        let facts = CoachHealthReport.facts(
            measures: [
                CoachHealthMeasureFacts(
                    measure: .restingHeartRate,
                    days: [CoachHealthDayValue(dateKey: "2026-10-10", average: 54)]
                )
            ],
            startKey: "2026-10-08",
            endKey: "2026-10-10",
            todayKey: "2026-10-10"
        )
        XCTAssertTrue(facts.text.contains("54 bpm"))
        XCTAssertTrue(facts.text.contains("2 days have no record"))
        XCTAssertFalse(facts.text.contains("zero"))
        XCTAssertEqual(facts.chart?.points.map(\.dateKey), ["2026-10-10"])
    }

    func test_bloodPressureKeepsEachReading() {
        let facts = CoachHealthReport.facts(
            measures: [
                CoachHealthMeasureFacts(
                    measure: .bloodPressure,
                    days: [
                        CoachHealthDayValue(
                            dateKey: "2026-10-10",
                            readings: [
                                CoachHealthPressureReading(timeLabel: "7:12 AM", systolic: 118, diastolic: 76),
                                CoachHealthPressureReading(timeLabel: "9:40 PM", systolic: 124, diastolic: 80)
                            ]
                        )
                    ]
                )
            ],
            startKey: "2026-10-10",
            endKey: "2026-10-10",
            todayKey: "2026-10-10"
        )
        XCTAssertTrue(facts.text.contains("7:12 AM: 118/76 mmHg"))
        XCTAssertTrue(facts.text.contains("9:40 PM: 124/80 mmHg"))
        XCTAssertFalse(facts.text.contains("average"))
    }

    func test_cardioFitnessKeepsTheLatestDate() {
        let facts = CoachHealthReport.facts(
            measures: [
                CoachHealthMeasureFacts(
                    measure: .cardioFitness,
                    latest: CoachHealthLatest(value: 42.5, dateKey: "2026-08-02")
                )
            ],
            startKey: "2026-10-10",
            endKey: "2026-10-10",
            todayKey: "2026-10-10"
        )
        XCTAssertTrue(facts.hasRecord)
        XCTAssertTrue(facts.text.contains("42.5 mL/kg/min"))
        XCTAssertTrue(facts.text.contains("2026") || facts.text.contains("August"))
        XCTAssertTrue(facts.text.contains("no record"))
    }

    func test_runIncludesPacePowerAndHeartRate() {
        let facts = CoachHealthReport.facts(
            measures: [
                CoachHealthMeasureFacts(
                    measure: .running,
                    runs: [
                        CoachHealthRun(
                            dateKey: "2026-10-10",
                            timeLabel: "6:10 AM",
                            durationMinutes: 32,
                            distanceMeters: 5_100,
                            averageSpeedMetersPerSecond: 1_000.0 / 376.0,
                            averagePowerWatts: 248,
                            averageHeartRate: 152
                        )
                    ],
                    distanceUsesMetric: true
                )
            ],
            startKey: "2026-10-10",
            endKey: "2026-10-10",
            todayKey: "2026-10-10"
        )
        XCTAssertTrue(facts.text.contains("32 min"))
        XCTAssertTrue(facts.text.contains("5.10 km"))
        XCTAssertTrue(facts.text.contains("6:16 /km"))
        XCTAssertTrue(facts.text.contains("248 W"))
        XCTAssertTrue(facts.text.contains("152 bpm"))
        XCTAssertEqual(facts.chart?.points.count, 1)
    }

    @MainActor
    func test_lookupHealthAsksForAMeasureAndDoesNotMentionTheScore() async {
        let live = CoachLiveContext()
        live.todayKey = "2026-10-10"
        let text = await live.healthPayload(measures: "", startDate: nil, endDate: nil, startDaysAgo: nil, endDaysAgo: nil)
        XCTAssertTrue(text.contains("restingHeartRate"))
        XCTAssertTrue(text.contains("running"))
        XCTAssertFalse(text.localizedCaseInsensitiveContains("score"))
    }

    @MainActor
    func test_showHealthChartUsesTheLookupAndLeavesTheScoreChartAlone() async {
        let live = CoachLiveContext()
        live.todayKey = "2026-10-10"
        live.healthLookup = { _, _, _ in
            CoachHealthFacts(text: "Resting heart rate: 54 bpm.", hasRecord: true, chart: nil)
        }
        let text = await live.showHealthChart(metric: "resting heart rate")
        XCTAssertTrue(text.hasPrefix("Chart shown"))
        XCTAssertEqual(live.pendingHealthChart, CoachHealthMeasure.restingHeartRate.rawValue)
        XCTAssertNil(live.pendingTrend)
    }
}
