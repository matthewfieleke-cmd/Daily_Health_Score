import XCTest
@testable import DailyHealthScore

final class CoachInsightRecordTests: XCTestCase {
    private let settings = UserSettings(sleepGoal: .sevenHalf, fiberGoal: .forty)
    private let today = "2026-09-20"

    func test_twoSleepDaysAreLeftOutAndThreeAreIncluded() {
        let thin = CoachInsightRecord.make(
            records: [record("2026-09-18", sleep: 6), record("2026-09-19", sleep: 6)],
            settings: settings,
            weight: nil,
            goals: [],
            measures: [],
            workouts: [],
            todayKey: today
        )
        XCTAssertTrue(thin.isEmpty)

        let enough = CoachInsightRecord.make(
            records: [
                record("2026-09-17", sleep: 6),
                record("2026-09-18", sleep: 6),
                record("2026-09-19", sleep: 6),
                record(today, sleep: 9)
            ],
            settings: settings,
            weight: nil,
            goals: [],
            measures: [],
            workouts: [],
            todayKey: today
        )
        XCTAssertFalse(enough.isEmpty)
        XCTAssertTrue(enough.text.contains("Sleep"))
        XCTAssertTrue(enough.text.contains("6 hr"))
        XCTAssertFalse(enough.text.contains("9 hr"))
        XCTAssertTrue(enough.text.contains("across 3 days"))
    }

    func test_threeBloodPressureReadingsStayBesideALongerHeartRateSeries() {
        let pressure = CoachHealthDayValue(
            dateKey: "2026-09-18",
            readings: [
                CoachHealthPressureReading(timeLabel: "7:00 AM", systolic: 140, diastolic: 90),
                CoachHealthPressureReading(timeLabel: "7:05 AM", systolic: 150, diastolic: 90),
                CoachHealthPressureReading(timeLabel: "7:10 AM", systolic: 130, diastolic: 90)
            ]
        )
        let heartDays = (0..<40).compactMap { offset -> CoachHealthDayValue? in
            guard let key = DateHelpers.addDays(to: "2026-09-19", days: -offset) else { return nil }
            return CoachHealthDayValue(dateKey: key, average: 70)
        }
        let packet = CoachInsightRecord.make(
            records: [],
            settings: settings,
            weight: nil,
            goals: [],
            measures: [
                CoachHealthMeasureFacts(measure: .bloodPressure, days: [pressure]),
                CoachHealthMeasureFacts(measure: .heartRate, days: heartDays)
            ],
            workouts: [],
            todayKey: today
        )
        XCTAssertTrue(packet.text.contains("Blood pressure"))
        XCTAssertTrue(packet.text.contains("3 readings"))
        XCTAssertTrue(packet.text.contains("Heart rate"))
        XCTAssertTrue(packet.text.contains("across 40 days"))
        XCTAssertFalse(packet.text.lowercased().contains("preferred"))
        let pressureIndex = packet.text.range(of: "Blood pressure")
        let heartIndex = packet.text.range(of: "Heart rate")
        XCTAssertNotNil(pressureIndex)
        XCTAssertNotNil(heartIndex)
    }

    func test_weightNeedsThreeReadingsAndReportsTheDirection() {
        var thin = BodyTrend(readingCount: 2)
        thin.changeOverFourWeeks = -2
        let omitted = CoachInsightRecord.make(
            records: [],
            settings: settings,
            weight: thin,
            goals: [],
            measures: [],
            workouts: [],
            todayKey: today
        )
        XCTAssertTrue(omitted.isEmpty)

        var trend = BodyTrend(readingCount: 3)
        trend.unit = .pounds
        trend.changeOverFourWeeks = -2.3
        let packet = CoachInsightRecord.make(
            records: [],
            settings: settings,
            weight: trend,
            goals: [CoachTestFixtures.goal(text: "Walk after dinner")],
            measures: [],
            workouts: [],
            todayKey: today
        )
        XCTAssertTrue(packet.text.contains("Weight"))
        XCTAssertTrue(packet.text.contains("Down"))
        XCTAssertTrue(packet.text.contains("Walk after dinner"))
        XCTAssertTrue(packet.text.contains("A goal is not a finding."))
    }

    func test_panelsKeepOneMetricAndDropInventedTopics() {
        let record = "Sleep\nWeight"
        let panels = CoachInsightRecord.panels(
            greenTopic: "Sleep",
            greenFinding: "The last week of sleep lengthened.",
            greenAdvice: "Maintain the Green. Keep that bedtime.",
            yellowTopic: "Sleep",
            yellowFinding: "The same metric again.",
            yellowAdvice: "Watch it.",
            redTopic: "Mindfulness",
            redFinding: "A reading that was not in the record.",
            redAdvice: "Breathe.",
            recordText: record
        )
        XCTAssertEqual(panels.map(\.tone), [.green, .yellow, .red])
        XCTAssertEqual(panels[0].topic, "Sleep")
        XCTAssertEqual(panels[0].advice, "Keep that bedtime.")
        XCTAssertTrue(panels[1].isBlank)
        XCTAssertTrue(panels[2].isBlank)

        let card = CoachCheckIn(
            kind: .morning,
            dateKey: today,
            healthLine: "",
            insights: panels
        )
        XCTAssertTrue(card.spokenText.contains("Green, Sleep"))
        XCTAssertTrue(card.spokenText.contains("Keep that bedtime."))
        XCTAssertFalse(card.spokenText.contains("Yellow"))
        XCTAssertFalse(card.spokenText.contains("Mindfulness"))
    }

    func test_waitingCardAsksForAppleHealthData() {
        let card = CoachInsightRecord.waitingCard(dateKey: today, kind: .morning, now: Date(timeIntervalSince1970: 0))
        XCTAssertTrue(card.waitingForHealthData)
        XCTAssertEqual(card.spokenText, CoachInsightRecord.needsDataSentence)
    }

    func test_olderCardDecodesWithoutInsights() throws {
        let json = """
        {"kind":"morning","dateKey":"2026-09-20","healthLine":"Older note.","thoughts":["Older note."]}
        """
        let card = try JSONDecoder().decode(CoachCheckIn.self, from: Data(json.utf8))
        XCTAssertEqual(card.healthLine, "Older note.")
        XCTAssertTrue(card.insights.isEmpty)
        XCTAssertFalse(card.waitingForHealthData)
        XCTAssertEqual(card.spokenText, "Older note.")
    }

    private func record(_ date: String, sleep: Double) -> DailyRecord {
        let metrics = DailyMetrics(sleepHours: sleep, fiberGrams: 0, exerciseMinutes: 0)
        let scores = ScoreCalculator.calculate(metrics: metrics, settings: settings)
        return DailyRecord(
            date: date,
            sleepHours: sleep,
            fiberGrams: 0,
            exerciseMinutes: 0,
            sleepHrvSDNNMs: nil,
            sleepGoal: settings.sleepGoal,
            fiberGoal: settings.fiberGoal,
            sleepScore: scores.sleepScore,
            fiberScore: scores.fiberScore,
            exerciseScore: scores.exerciseScore,
            totalScore: scores.totalScore,
            sleepPercent: scores.sleepPercent,
            fiberPercent: scores.fiberPercent,
            exercisePercent: scores.exercisePercent,
            primaryFocus: .sleep,
            suggestion: "",
            suggestionPhase: .day,
            createdAt: Date(timeIntervalSince1970: 0),
            updatedAt: Date(timeIntervalSince1970: 0)
        )
    }
}
