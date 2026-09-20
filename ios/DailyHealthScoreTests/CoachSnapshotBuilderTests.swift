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

    func test_charter_namesIdentityStandardsAndSafety() {
        let charter = CoachCharter.instructions
        XCTAssertTrue(CoachCharter.philosophy.contains("acceptance"))
        XCTAssertTrue(charter.contains("three Ivy League doctorates"))
        XCTAssertTrue(charter.contains("exercise science"))
        XCTAssertTrue(charter.contains("nutrition science"))
        XCTAssertTrue(charter.contains("behavioral psychology"))
        XCTAssertTrue(charter.contains("American Board of Lifestyle Medicine"))
        XCTAssertTrue(charter.contains("world-renowned motivational speaker"))
        XCTAssertTrue(charter.contains("name your credentials"))
        XCTAssertTrue(charter.contains("HOW YOU ANSWER"))
        XCTAssertTrue(charter.contains("Answer what was actually asked in your first sentence"))
        XCTAssertTrue(charter.contains("never with technique names or jargon"))
        XCTAssertTrue(charter.contains("NUMBERS"))
        XCTAssertTrue(charter.contains("NO DATA, BELOW GOAL, GOAL MET, GOAL EXCEEDED"))
        XCTAssertTrue(charter.contains("MEMORY FILES"))
        XCTAssertTrue(charter.contains("trigger, tell, and antidote"))
        XCTAssertTrue(charter.contains("SAFETY"))
        XCTAssertTrue(charter.contains("Please seek immediate medical attention or professional help."))
        XCTAssertTrue(charter.contains("988"))
        XCTAssertTrue(charter.contains("never praise weight"))
        XCTAssertTrue(charter.contains("\(CoachCharter.maxReplyWords) words"))
        // Trimmed on purpose: no per-intent contracts, no technique scripts, no quoted mantra rule.
        XCTAssertFalse(charter.contains("RESPONSE CONTRACT"))
        XCTAssertFalse(charter.contains("TIPP"))
        XCTAssertFalse(charter.contains("0 to 10"))
        XCTAssertLessThan(charter.count, 12_000)
        XCTAssertTrue(charter.contains("VOICE"))
        XCTAssertTrue(charter.contains("REGISTER"))
        XCTAssertTrue(charter.contains("never paraphrase the message back"))
        XCTAssertTrue(charter.contains("WRITING FOR THEM"))
        XCTAssertTrue(charter.contains("would you have said it to a stranger"))
        XCTAssertTrue(charter.contains("When the files are thin"))
        XCTAssertTrue(charter.contains("never a bare word"))
        XCTAssertTrue(charter.contains("Recognize danger"))
        XCTAssertTrue(charter.contains("therapist who works with"))
        XCTAssertTrue(charter.contains("Overwhelm and burnout"))
        XCTAssertTrue(charter.contains("HRV comes up only when they ask"))
        XCTAssertTrue(charter.contains("not guess it; ask or leave it out"))
        XCTAssertTrue(charter.contains("never narrate it"))
        XCTAssertTrue(charter.contains("while driving"))
        XCTAssertTrue(charter.contains("never as a report on today"))
        XCTAssertTrue(charter.contains("room, not a quota"))
        XCTAssertTrue(charter.contains("Sensitive topics"))
        XCTAssertTrue(charter.contains("Recognize danger first and triage it, then help"))
        XCTAssertTrue(CoachCharter.onDeviceInstructions.contains("never guess them"))
        XCTAssertTrue(CoachCharter.onDeviceInstructions.contains("while driving"))
        // Principles, never scripts: no quoted example sentences a model could copy,
        // except the one fixed crisis line and the philosophy.
        let quoted = charter.components(separatedBy: "\"").enumerated().filter { $0.offset % 2 == 1 }.map(\.element)
        let sentences = quoted.filter { $0.count > 24 && $0 != CoachSafetyGate.immediateHelpSentence && $0 != CoachCharter.philosophy }
        XCTAssertEqual(sentences, [], "Example sentences become scripts: \(sentences)")

        // The on-device charter is the same coach in far fewer words.
        let short = CoachCharter.onDeviceInstructions
        XCTAssertLessThan(short.count, charter.count / 3)
        XCTAssertTrue(short.contains("never paraphrase"))
        XCTAssertTrue(short.contains(CoachSafetyGate.immediateHelpSentence))
        XCTAssertTrue(short.contains("stranger"))
        XCTAssertEqual(CoachCharter.instructions(for: .privateCloud), charter)
        XCTAssertEqual(CoachCharter.instructions(for: .onDevice), short)
        // Goal work keeps the voice and adds shaping.
        let goal = CoachCharter.goalPlanningInstructions(for: .privateCloud)
        XCTAssertTrue(goal.hasPrefix(charter))
        XCTAssertTrue(goal.contains("GOAL SHAPING"))
        XCTAssertTrue(goal.contains("sensible defaults"))
        XCTAssertTrue(CoachCharter.goalPlanningInstructions(for: .onDevice).hasPrefix(short))
        XCTAssertTrue(CoachCharter.outputContract.contains("memoryUpdates"))
        XCTAssertTrue(CoachCharter.outputContract.contains("basis"))
        XCTAssertTrue(CoachCharter.acquaintanceContract().contains("what to call them"))
        XCTAssertTrue(CoachCharter.acquaintanceContract().contains("Every file has something now."))
        let intake = CoachCharter.acquaintanceContract(emptyFiles: ["People", "Body & health"])
        XCTAssertTrue(intake.contains("NEXT FILE TO ASK ABOUT: People."))
        XCTAssertTrue(intake.contains("Still empty after it: Body & health."))
        XCTAssertTrue(intake.contains("exactly one file per message"))
        let morning = CoachCharter.checkInContract(kind: .morning, hasTrend: true)
        XCTAssertTrue(morning.contains("healthLine"))
        XCTAssertTrue(morning.contains("question"))
        XCTAssertTrue(morning.contains("TIME RULES"))
        XCTAssertTrue(morning.contains("TREND FACTS"))
        XCTAssertTrue(morning.contains("Never write a number"))
        let evening = CoachCharter.checkInContract(kind: .evening, hasTrend: false)
        XCTAssertTrue(evening.contains("tomorrowLine"))
        XCTAssertTrue(evening.contains("Tomorrow"))
        XCTAssertTrue(evening.contains("Never write a number"))
        XCTAssertTrue(CoachCharter.filingInstructions.contains("threadTitle"))
        XCTAssertTrue(CoachCharter.reviewInstructions.contains("Never invent facts"))
    }

    func test_promptBlockIncludesLocalClockAndEveningTimeRules() {
        let calendar = chicagoCalendar()
        let sixPM = date(calendar: calendar, hour: 18, minute: 0)
        let record = makeRecord(date: "2026-08-16", sleep: 7.2, fiber: 12, exercise: 2, focus: .fiber)
        let snapshot = CoachSnapshotBuilder.build(
            today: record,
            records: [record],
            phase: .day,
            now: sixPM,
            calendar: calendar
        )

        XCTAssertEqual(snapshot.timeOfDay, .evening)
        XCTAssertTrue(snapshot.clockLabel.contains("evening"))
        XCTAssertTrue(snapshot.promptBlock.contains("LOCAL CLOCK"))
        XCTAssertTrue(snapshot.promptBlock.contains("TIME RULES"))
        XCTAssertTrue(snapshot.promptBlock.contains("Do not"))
        XCTAssertTrue(snapshot.promptBlock.lowercased().contains("after lunch"))
        XCTAssertTrue(snapshot.minimalBlock.contains("LOCAL CLOCK"))
        XCTAssertTrue(snapshot.minimalBlock.contains("TIME RULES"))
    }

    func test_checkIn_roundTripsThroughJSONAndSpeaksInOrder() throws {
        let replyID = UUID()
        let card = CoachCheckIn(
            kind: .evening,
            dateKey: "2026-08-16",
            healthLine: "Today landed at 6 of 10.",
            question: "What got in the way?",
            tomorrowLine: "Tomorrow, one thing: shoes by the door.",
            replyThreadID: replyID
        )
        let decoded = try JSONDecoder().decode(CoachCheckIn.self, from: JSONEncoder().encode(card))
        XCTAssertEqual(decoded, card)
        XCTAssertEqual(
            decoded.spokenText,
            "Today landed at 6 of 10. Tomorrow, one thing: shoes by the door. What got in the way?"
        )
        XCTAssertTrue(decoded.hasReply)
    }

    private func chicagoCalendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Chicago")!
        return calendar
    }

    private func date(calendar: Calendar, hour: Int, minute: Int) -> Date {
        var components = DateComponents()
        components.year = 2026
        components.month = 8
        components.day = 16
        components.hour = hour
        components.minute = minute
        return calendar.date(from: components)!
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
