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

    func test_smallTalkDoesNotBecomeCoaching() {
        XCTAssertEqual(CoachIntentClassifier.classify("What day is it today?"), .smallTalk)
        XCTAssertEqual(CoachIntentClassifier.classify("Good morning"), .smallTalk)
        XCTAssertEqual(CoachIntentClassifier.classify("Thanks!"), .smallTalk)
    }

    func test_recommendationAndComparisonQuestionsAreEducation() {
        XCTAssertEqual(CoachIntentClassifier.classify("What should I have for breakfast?"), .education)
        XCTAssertEqual(CoachIntentClassifier.classify("What is better? Walking or running?"), .education)
        XCTAssertEqual(CoachIntentClassifier.classify("Which is better for sleep, tea or milk?"), .education)
    }

    func test_onlyPlanIntentsMayOfferANextStep() {
        XCTAssertFalse(CoachIntent.smallTalk.allowsNextStep)
        XCTAssertFalse(CoachIntent.education.allowsNextStep)
        XCTAssertFalse(CoachIntent.dataLookup.allowsNextStep)
        XCTAssertTrue(CoachIntent.planning.allowsNextStep)
        XCTAssertTrue(CoachIntent.support.allowsNextStep)
    }

    func test_metricsAreWithheldFromEducationAndSmallTalk() {
        XCTAssertFalse(CoachIntent.education.usesFullMetrics)
        XCTAssertFalse(CoachIntent.smallTalk.usesFullMetrics)
        XCTAssertTrue(CoachIntent.dataLookup.usesFullMetrics)
        XCTAssertTrue(CoachIntent.planning.usesFullMetrics)
    }

    func test_contractsEncodeCriticalRules() {
        XCTAssertTrue(CoachIntent.education.contract.contains("Do NOT recite the user's daily metrics"))
        XCTAssertTrue(CoachIntent.dataLookup.contract.contains("including the goal value"))
        XCTAssertTrue(CoachIntent.planning.contract.contains("Never write \"I will ...\" as yourself."))
        XCTAssertTrue(CoachIntent.support.contract.contains("Validate the feeling first"))
        XCTAssertTrue(CoachIntent.smallTalk.contract.contains("No metrics"))
        XCTAssertTrue(CoachIntent.education.contract.contains("Be concrete"))
    }
}
