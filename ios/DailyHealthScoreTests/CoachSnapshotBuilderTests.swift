import XCTest
@testable import DailyHealthScore

final class CoachSnapshotBuilderTests: XCTestCase {
    func test_build_marksMissingFiberAndIncludesWeekFiberLoggingCount() {
        let today = makeRecord(
            date: "2026-08-10",
            sleep: 7.0,
            fiber: 0,
            exercise: 20,
            focus: .fiber
        )
        let earlier = makeRecord(
            date: "2026-08-09",
            sleep: 6.5,
            fiber: 22,
            exercise: 30,
            focus: .sleep
        )

        let snapshot = CoachSnapshotBuilder.build(
            today: today,
            records: [today, earlier],
            phase: .day
        )

        XCTAssertEqual(snapshot.todayKey, "2026-08-10")
        XCTAssertEqual(snapshot.primaryFocus, .fiber)
        XCTAssertFalse(snapshot.fiberPresentToday)
        XCTAssertTrue(snapshot.sleepPresentToday)
        XCTAssertEqual(snapshot.fiberDaysLoggedInWeek, 1)
        XCTAssertTrue(snapshot.promptBlock.contains("Implied focus from metrics: fiber"))
        XCTAssertTrue(snapshot.promptBlock.contains("fiber logging incomplete/missing"))
    }

    func test_profileMerge_keepsExistingWhenIncomingEmpty() {
        var profile = CoachUserProfile(
            preferredStyle: "gentle",
            constraints: "shift work",
            nutritionNotes: "",
            movementNotes: "walks",
            sleepNotes: "",
            values: "family",
            whatHelps: "small plans",
            whatToAvoid: "score nagging"
        )
        profile.merge(
            from: CoachUserProfile(
                preferredStyle: "",
                constraints: "early meetings",
                nutritionNotes: "likes beans",
                movementNotes: "",
                sleepNotes: "",
                values: "",
                whatHelps: "",
                whatToAvoid: ""
            )
        )

        XCTAssertEqual(profile.preferredStyle, "gentle")
        XCTAssertEqual(profile.constraints, "early meetings")
        XCTAssertEqual(profile.nutritionNotes, "likes beans")
        XCTAssertEqual(profile.movementNotes, "walks")
        XCTAssertEqual(profile.values, "family")
    }

    func test_charter_containsAcceptancePhilosophy() {
        XCTAssertTrue(CoachCharter.philosophy.contains("acceptance"))
        XCTAssertTrue(CoachCharter.instructions.contains("Motivational Interviewing"))
        XCTAssertTrue(CoachCharter.instructions.contains("DBT"))
        XCTAssertTrue(CoachCharter.instructions.contains("source of truth"))
    }

    private func makeRecord(
        date: String,
        sleep: Double,
        fiber: Double,
        exercise: Double,
        focus: PrimaryFocus
    ) -> DailyRecord {
        let metrics = DailyMetrics(
            sleepHours: sleep,
            fiberGrams: fiber,
            exerciseMinutes: exercise
        )
        let settings = UserSettings(sleepGoal: .sevenHalf, fiberGoal: .forty)
        let scores = ScoreCalculator.calculate(metrics: metrics, settings: settings)
        return DailyRecord(
            date: date,
            sleepHours: sleep,
            fiberGrams: fiber,
            exerciseMinutes: exercise,
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
            primaryFocus: focus,
            suggestion: "",
            suggestionPhase: .day,
            createdAt: Date(timeIntervalSince1970: 0),
            updatedAt: Date(timeIntervalSince1970: 0)
        )
    }
}
