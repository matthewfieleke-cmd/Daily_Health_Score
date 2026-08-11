import XCTest
@testable import DailyHealthScore

final class CoachDataSummariesTests: XCTestCase {
    private let calendar = Calendar.current

    private func goal(
        text: String = "walk after dinner",
        target: Int,
        filled: Int,
        endsInDays: Int,
        status: SMARTGoalStatus = .active
    ) -> SMARTGoal {
        var mask = 0
        for index in 0 ..< filled { mask |= (1 << index) }
        return SMARTGoal(
            id: UUID(),
            specificText: text,
            targetCount: target,
            relevantTheme: .health,
            timeWindowDays: 7,
            endDate: calendar.date(byAdding: .day, value: endsInDays, to: Date())!,
            createdAt: Date(),
            generatedSummary: "",
            filledMask: mask,
            status: status,
            remindersEnabled: false,
            reminderHour: 9,
            reminderMinute: 0,
            reminderWeekdaysMask: 127
        )
    }

    // MARK: - SMART goals

    func test_onPaceGoalReportsComputedProgressAndDaysLeft() {
        let line = CoachGoalSummarizer.line(for: goal(target: 5, filled: 3, endsInDays: 4))

        XCTAssertTrue(line.contains("3 of 5 check-ins"))
        XCTAssertTrue(line.contains("4 days left"))
        XCTAssertTrue(line.contains("ON TRACK"))
        XCTAssertTrue(line.contains("2 to go"))
    }

    func test_behindPaceIsJudgedInSwift() {
        // Five check-ins left with only two days to do them in.
        let line = CoachGoalSummarizer.line(for: goal(target: 6, filled: 1, endsInDays: 2))

        XCTAssertTrue(line.contains("BEHIND PACE"))
        XCTAssertFalse(line.contains("ON TRACK"))
    }

    func test_completedGoalIsProtectedRatherThanExtended() {
        let line = CoachGoalSummarizer.line(for: goal(target: 3, filled: 3, endsInDays: 5))

        XCTAssertTrue(line.contains("COMPLETE"))
        XCTAssertTrue(line.contains("do not assign more"))
    }

    func test_endedGoalIsFramedWithoutJudgement() {
        let line = CoachGoalSummarizer.line(for: goal(target: 5, filled: 2, endsInDays: -1))

        XCTAssertTrue(line.contains("ENDED"))
        XCTAssertTrue(line.contains("not a verdict"))
    }

    func test_goalEndingTodayReadsAsToday() {
        let line = CoachGoalSummarizer.line(for: goal(target: 4, filled: 3, endsInDays: 0))

        XCTAssertTrue(line.contains("ends today"))
    }

    func test_pastDeadlineNeverReportsNegativeDays() {
        let past = calendar.date(byAdding: .day, value: -5, to: Date())!

        XCTAssertEqual(CoachGoalSummarizer.daysRemaining(until: past, from: Date()), 0)
    }

    func test_activeGoalsLeadAndListIsCapped() {
        let goals = [
            goal(text: "done", target: 2, filled: 2, endsInDays: 1),
            goal(text: "active a", target: 5, filled: 1, endsInDays: 6),
            goal(text: "active b", target: 5, filled: 1, endsInDays: 2),
            goal(text: "active c", target: 5, filled: 1, endsInDays: 9),
            goal(text: "active d", target: 5, filled: 1, endsInDays: 11),
            goal(text: "active e", target: 5, filled: 1, endsInDays: 13)
        ]

        let lines = CoachGoalSummarizer.lines(for: goals)

        XCTAssertEqual(lines.count, CoachGoalSummarizer.maxGoalsInPrompt)
        // Nearest active deadline first; the finished goal is crowded out.
        XCTAssertTrue(lines[0].contains("active b"))
        XCTAssertFalse(lines.contains { $0.contains("\"done\"") })
    }

    func test_longGoalTextCannotCrowdOutThePrompt() {
        let sprawling = String(repeating: "a very long goal statement ", count: 20)
        let line = CoachGoalSummarizer.line(for: goal(text: sprawling, target: 3, filled: 1, endsInDays: 3))

        XCTAssertLessThan(line.count, 200)
    }

    func test_noGoalsProducesNoLines() {
        XCTAssertTrue(CoachGoalSummarizer.lines(for: []).isEmpty)
    }

    // MARK: - HRV

    private func record(dayOffset: Int, hrv: Double?) -> DailyRecord {
        let key = DateHelpers.addDays(to: DateHelpers.localDateKey(), days: -dayOffset)!
        let metrics = DailyMetrics(sleepHours: 7.2, fiberGrams: 30, exerciseMinutes: 30)
        let settings = UserSettings(sleepGoal: .sevenHalf, fiberGoal: .forty)
        let scores = ScoreCalculator.calculate(metrics: metrics, settings: settings)
        return DailyRecord(
            date: key,
            sleepHours: metrics.sleepHours,
            fiberGrams: metrics.fiberGrams,
            exerciseMinutes: metrics.exerciseMinutes,
            sleepHrvSDNNMs: hrv,
            sleepGoal: settings.sleepGoal,
            fiberGoal: settings.fiberGoal,
            sleepScore: scores.sleepScore,
            fiberScore: scores.fiberScore,
            exerciseScore: scores.exerciseScore,
            totalScore: scores.totalScore,
            sleepPercent: scores.sleepPercent,
            fiberPercent: scores.fiberPercent,
            exercisePercent: scores.exercisePercent,
            primaryFocus: .fiber,
            suggestion: "",
            suggestionPhase: .day,
            createdAt: Date(timeIntervalSince1970: 0),
            updatedAt: Date(timeIntervalSince1970: 0)
        )
    }

    func test_readyBaselineDescribesThePersonalCorridor() {
        let records = (0 ..< 40).map { record(dayOffset: $0, hrv: 45 + Double($0 % 7)) }
        let analysis = HRVBaselineAnalyzer.analyze(
            records: records,
            todayKey: DateHelpers.localDateKey(),
            sensitivity: .balanced
        )

        let line = CoachHRVSummarizer.line(for: analysis)

        XCTAssertTrue(line.contains("usual range"))
        XCTAssertTrue(line.contains("not diagnostic"))
        XCTAssertTrue(line.contains("never diagnose"))
    }

    func test_thinHistorySaysSoInsteadOfGuessing() {
        let records = (0 ..< 3).map { record(dayOffset: $0, hrv: 50) }
        let analysis = HRVBaselineAnalyzer.analyze(
            records: records,
            todayKey: DateHelpers.localDateKey(),
            sensitivity: .balanced
        )

        let line = CoachHRVSummarizer.line(for: analysis)

        XCTAssertTrue(line.contains("building a personal baseline"))
        XCTAssertFalse(line.contains("usual range of"))
    }

    // MARK: - Snapshot integration

    func test_snapshotCarriesGoalsAndHRVIntoThePrompt() {
        let records = (0 ..< 40).map { record(dayOffset: $0, hrv: 48) }
        let snapshot = CoachSnapshotBuilder.build(
            today: records[0],
            records: records,
            goals: [goal(target: 5, filled: 2, endsInDays: 3)],
            hrvSensitivity: .balanced
        )

        XCTAssertTrue(snapshot.promptBlock.contains("SMART GOALS"))
        XCTAssertNotNil(snapshot.hrvSummary)
        XCTAssertTrue(snapshot.promptBlock.contains("HRV"))
    }

    func test_minimalBlockStillWithholdsGoalsAndMetrics() {
        let records = (0 ..< 40).map { record(dayOffset: $0, hrv: 48) }
        let snapshot = CoachSnapshotBuilder.build(
            today: records[0],
            records: records,
            goals: [goal(target: 5, filled: 2, endsInDays: 3)],
            hrvSensitivity: .balanced
        )

        // Education questions must not drag today's numbers into the answer.
        XCTAssertFalse(snapshot.minimalBlock.contains("SMART GOALS"))
        XCTAssertFalse(snapshot.minimalBlock.contains("HRV"))
    }

    func test_untrackedHRVIsNotMentionedAtAll() {
        let records = (0 ..< 10).map { record(dayOffset: $0, hrv: nil) }
        let snapshot = CoachSnapshotBuilder.build(today: records[0], records: records)

        XCTAssertNil(snapshot.hrvSummary)
        XCTAssertFalse(snapshot.promptBlock.contains("HRV"))
    }
}
