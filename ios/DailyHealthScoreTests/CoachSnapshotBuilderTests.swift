import XCTest
@testable import DailyHealthScore

final class CoachSnapshotBuilderTests: XCTestCase {
    func test_fiberBelowGoal_isNeverDescribedAsAboveGoal() {
        let status = CoachSnapshotBuilder.status(
            name: "Fiber",
            value: 36.8,
            goal: 40,
            unit: "g",
            decimals: 1,
            points: 3.7,
            maxPoints: 4
        )

        XCTAssertEqual(status.level, .below)
        XCTAssertFalse(status.isAtOrAboveGoal)
        XCTAssertTrue(status.sentence.contains("BELOW GOAL by 3.2 g"))
        XCTAssertTrue(status.sentence.contains("of a 40 g goal"))
        XCTAssertTrue(status.sentence.contains("92% of goal"))
        XCTAssertFalse(status.sentence.contains("EXCEEDED"))
    }

    func test_goalMetAndExceededAreDistinguished() {
        let met = CoachSnapshotBuilder.status(
            name: "Sleep",
            value: 7.5,
            goal: 7.5,
            unit: "h",
            decimals: 1,
            points: 4,
            maxPoints: 4
        )
        XCTAssertEqual(met.level, .met)
        XCTAssertTrue(met.isAtOrAboveGoal)

        let exceeded = CoachSnapshotBuilder.status(
            name: "Exercise",
            value: 71,
            goal: 30,
            unit: "min",
            decimals: 0,
            points: 2,
            maxPoints: 2
        )
        XCTAssertEqual(exceeded.level, .exceeded)
        XCTAssertTrue(exceeded.sentence.contains("GOAL EXCEEDED by 41 min"))
    }

    func test_missingMetricIsNotTreatedAsZeroBehavior() {
        let status = CoachSnapshotBuilder.status(
            name: "Fiber",
            value: 0,
            goal: 40,
            unit: "g",
            decimals: 1,
            points: 0,
            maxPoints: 4
        )

        XCTAssertEqual(status.level, .missing)
        XCTAssertTrue(status.sentence.contains("NO DATA"))
        XCTAssertTrue(status.sentence.lowercased().contains("not necessarily zero"))
    }

    func test_snapshotStatesGoalsExplicitly() {
        let record = makeRecord(date: "2026-08-11", sleep: 7.2, fiber: 36.8, exercise: 71, focus: .sleep)
        let snapshot = CoachSnapshotBuilder.build(today: record, records: [record], phase: .evening)

        XCTAssertTrue(snapshot.goalsBlock.contains("Fiber goal 40 g/day"))
        XCTAssertTrue(snapshot.goalsBlock.contains("Sleep goal 7.5 h/night"))
        XCTAssertTrue(snapshot.goalsBlock.contains("Exercise goal 30 min/day"))
        XCTAssertTrue(snapshot.promptBlock.contains("USER'S GOALS"))
        XCTAssertTrue(snapshot.promptBlock.contains("BELOW GOAL by 3.2 g"))
    }

    func test_minimalBlockKeepsDateAndGoalsButHidesMetrics() {
        let record = makeRecord(date: "2026-08-11", sleep: 7.2, fiber: 36.8, exercise: 1, focus: .exercise)
        let snapshot = CoachSnapshotBuilder.build(today: record, records: [record], phase: .evening)

        XCTAssertTrue(snapshot.minimalBlock.contains("August"))
        XCTAssertTrue(snapshot.minimalBlock.contains("Fiber goal 40 g/day"))
        XCTAssertFalse(snapshot.minimalBlock.contains("BELOW GOAL"))
        XCTAssertTrue(snapshot.promptBlock.contains(snapshot.todayDisplay))
    }

    func test_coachingDirective_protectsMetPillarsAndTargetsWeakest() {
        let record = makeRecord(date: "2026-08-11", sleep: 7.2, fiber: 12, exercise: 71, focus: .fiber)
        let snapshot = CoachSnapshotBuilder.build(today: record, records: [record], phase: .day)

        let directive = snapshot.coachingDirective
        XCTAssertTrue(directive.contains("Exercise is already at or above goal"))
        XCTAssertTrue(directive.contains("do NOT ask for more exercise"))
        XCTAssertTrue(directive.contains("focus on fiber"))
    }

    func test_allGoalsMet_shiftsToMaintenance() {
        let record = makeRecord(date: "2026-08-11", sleep: 8.2, fiber: 45, exercise: 60, focus: .maintain)
        let snapshot = CoachSnapshotBuilder.build(today: record, records: [record], phase: .day)

        XCTAssertTrue(snapshot.coachingDirective.contains("All pillars met"))
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
    }

    func test_profileMerge_capsFieldLengthSoPromptsStaySmall() {
        var profile = CoachUserProfile()
        profile.merge(from: CoachUserProfile(constraints: String(repeating: "a", count: 500)))

        XCTAssertEqual(profile.constraints.count, CoachUserProfile.maxFieldLength)
    }

    func test_transcriptBlock_trimsTurnsAndLength() {
        let turns = (0..<10).map { index in
            CoachChatTurn(role: index.isMultiple(of: 2) ? .user : .coach, text: String(repeating: "x", count: 400))
        }

        let block = FoundationModelsCoach.transcriptBlock(turns)

        XCTAssertEqual(block.split(separator: "\n").count, 6)
        XCTAssertTrue(block.contains("…"))
        XCTAssertLessThan(block.count, 1_700)
    }

    func test_charter_encodesPhilosophyMethodsAndAnswerFirst() {
        XCTAssertTrue(CoachCharter.philosophy.contains("acceptance"))
        XCTAssertTrue(CoachCharter.instructions.contains("Motivational Interviewing"))
        XCTAssertTrue(CoachCharter.instructions.contains("DBT-informed"))
        XCTAssertTrue(CoachCharter.instructions.contains("ANSWER-FIRST RULE"))
        XCTAssertTrue(CoachCharter.instructions.contains("Never say someone is above goal"))
        XCTAssertTrue(CoachCharter.instructions.contains("Never state \"I will ...\" as your own plan."))
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
