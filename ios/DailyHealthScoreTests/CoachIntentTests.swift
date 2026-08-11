import XCTest
@testable import DailyHealthScore

final class CoachIntentTests: XCTestCase {
    func test_dataQuestionsRouteToDataLookup() {
        XCTAssertEqual(CoachIntentClassifier.classify("That's my goal?"), .dataLookup)
        XCTAssertEqual(CoachIntentClassifier.classify("What is my fiber goal"), .dataLookup)
        XCTAssertEqual(CoachIntentClassifier.classify("How much fiber did I have today?"), .dataLookup)
        XCTAssertEqual(CoachIntentClassifier.classify("How am I doing this week?"), .dataLookup)
    }

    func test_educationQuestionsRouteToEducation() {
        XCTAssertEqual(CoachIntentClassifier.classify("What is the healthiest vegetable?"), .education)
        XCTAssertEqual(CoachIntentClassifier.classify("Why does fiber matter?"), .education)
        XCTAssertEqual(CoachIntentClassifier.classify("What are good sources of protein?"), .education)
    }

    func test_supportOutranksOtherIntents() {
        XCTAssertEqual(
            CoachIntentClassifier.classify("I feel discouraged, what should I do?"),
            .support
        )
        XCTAssertEqual(CoachIntentClassifier.classify("I keep failing at this"), .support)
    }

    func test_planningRequests() {
        XCTAssertEqual(CoachIntentClassifier.classify("Help me build a routine"), .planning)
        XCTAssertEqual(CoachIntentClassifier.classify("How do I start strength training"), .planning)
    }

    func test_contractsEncodeCriticalRules() {
        XCTAssertTrue(CoachIntent.education.contract.contains("Do NOT recite the user's daily metrics"))
        XCTAssertTrue(CoachIntent.dataLookup.contract.contains("including the goal value"))
        XCTAssertTrue(CoachIntent.planning.contract.contains("Never write \"I will ...\" as yourself."))
        XCTAssertTrue(CoachIntent.support.contract.contains("Validate the feeling first"))
    }
}
