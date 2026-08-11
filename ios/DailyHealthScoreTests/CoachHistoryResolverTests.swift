import XCTest
@testable import DailyHealthScore

final class CoachHistoryResolverTests: XCTestCase {
    private let today = DateHelpers.localDateKey()

    private func record(on dateKey: String) -> DailyRecord {
        DailyRecord(
            date: dateKey,
            sleepHours: 6.2,
            fiberGrams: 36.8,
            exerciseMinutes: 45,
            sleepGoal: .sevenHalf,
            fiberGoal: .forty,
            sleepScore: 3.3,
            fiberScore: 3.7,
            exerciseScore: 2,
            totalScore: 9.0,
            sleepPercent: 0.83,
            fiberPercent: 0.92,
            exercisePercent: 1.0,
            primaryFocus: .fiber,
            suggestion: "",
            createdAt: Date(),
            updatedAt: Date()
        )
    }

    func test_yesterdayResolvesToPreviousDay() {
        let expected = DateHelpers.addDays(to: today, days: -1)
        XCTAssertEqual(
            CoachHistoryResolver.resolve(message: "How did I sleep yesterday?", todayKey: today).first?.dateKey,
            expected
        )
        XCTAssertEqual(
            CoachHistoryResolver.resolve(message: "I slept badly last night", todayKey: today).first?.dateKey,
            expected
        )
    }

    func test_weekdayResolvesToMostRecentPastOccurrence() {
        let references = CoachHistoryResolver.resolve(message: "what was my score last tuesday", todayKey: today)
        XCTAssertEqual(references.count, 1)
        guard let key = references.first?.dateKey, let date = DateHelpers.date(from: key) else {
            return XCTFail("expected a resolved date")
        }
        XCTAssertEqual(Calendar.current.component(.weekday, from: date), 3)
        XCTAssertLessThan(date, DateHelpers.date(from: today)!)
    }

    func test_futureAndAmbiguousReferencesAreNotHistory() {
        XCTAssertTrue(CoachHistoryResolver.resolve(message: "I'm starting Monday", todayKey: today).isEmpty)
        XCTAssertTrue(CoachHistoryResolver.resolve(message: "What should I do tomorrow?", todayKey: today).isEmpty)
        XCTAssertTrue(CoachHistoryResolver.resolve(message: "What is the healthiest vegetable?", todayKey: today).isEmpty)
    }

    /// The comparison is computed in Swift so the model never does the arithmetic.
    func test_blockStatesGoalComparisonsExactly() {
        let yesterday = DateHelpers.addDays(to: today, days: -1)!
        let block = CoachHistoryResolver.block(
            message: "how did I do yesterday?",
            records: [record(on: yesterday)],
            todayKey: today,
            characterBudget: 1400
        )
        XCTAssertNotNil(block)
        XCTAssertTrue(block!.contains("BELOW GOAL by 3.2 g"))
        XCTAssertTrue(block!.contains("BELOW GOAL by 1.3 h"))
        XCTAssertTrue(block!.contains("GOAL EXCEEDED by 15 min"))
    }

    func test_missingDaySaysSoRatherThanInventingNumbers() {
        let block = CoachHistoryResolver.block(
            message: "how did I do yesterday?",
            records: [],
            todayKey: today,
            characterBudget: 900
        )
        XCTAssertEqual(block?.contains("no record saved"), true)
    }

    func test_noReferenceProducesNoBlock() {
        XCTAssertNil(
            CoachHistoryResolver.block(
                message: "what is the healthiest vegetable",
                records: [record(on: today)],
                todayKey: today,
                characterBudget: 900
            )
        )
    }
}
