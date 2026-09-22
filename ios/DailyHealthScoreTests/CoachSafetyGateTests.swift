import XCTest
@testable import DailyHealthScore

final class CoachSafetyGateTests: XCTestCase {
    func test_ordinaryMessagesPassThrough() {
        XCTAssertEqual(CoachSafetyGate.evaluate("How do I add more fiber?"), .ordinary)
        XCTAssertEqual(CoachSafetyGate.evaluate("My knee hurts when I walk"), .ordinary)
        XCTAssertEqual(CoachSafetyGate.evaluate("Should I take creatine?"), .ordinary)
    }

    func test_selfHarmEscalatesDeterministically() {
        guard case .escalate(let message) = CoachSafetyGate.evaluate("I want to kill myself") else {
            return XCTFail("Expected escalation")
        }
        XCTAssertTrue(message.contains(CoachSafetyGate.immediateHelpSentence))
        XCTAssertTrue(message.contains("988"))
    }

    func test_harmToOthersEscalatesDeterministically() {
        guard case .escalate(let message) = CoachSafetyGate.evaluate("I want to hurt someone") else {
            return XCTFail("Expected escalation")
        }
        XCTAssertTrue(message.contains(CoachSafetyGate.immediateHelpSentence))
        XCTAssertTrue(message.lowercased().contains("emergency"))
    }

    func test_chestPainEscalates() {
        guard case .escalate(let message) = CoachSafetyGate.evaluate("I have chest pain when walking") else {
            return XCTFail("Expected escalation")
        }
        XCTAssertTrue(message.contains(CoachSafetyGate.immediateHelpSentence))
        XCTAssertTrue(message.lowercased().contains("emergency"))
    }

    func test_disorderedEatingEscalates() {
        guard case .escalate(let message) = CoachSafetyGate.evaluate("I make myself throw up after eating") else {
            return XCTFail("Expected escalation")
        }
        XCTAssertTrue(message.contains(CoachSafetyGate.immediateHelpSentence))
    }

    /// Below an emergency there is still something to take care of: the model is
    /// told, and the app can answer if the model declines.
    func test_concernsAreRecognizedWithoutEscalating() {
        XCTAssertEqual(
            CoachSafetyGate.evaluate("Fighting with my wife often triggers binge-eating. I do it because I'm feeling overwhelmed."),
            .concern(.eating),
            "Eating outranks strain when both are present"
        )
        XCTAssertEqual(CoachSafetyGate.evaluate("I've been drinking too much since the move."), .concern(.substance))
        XCTAssertEqual(CoachSafetyGate.evaluate("Honestly everything feels hopeless lately."), .concern(.mood))
        XCTAssertEqual(CoachSafetyGate.evaluate("I'm completely overwhelmed at work."), .concern(.strain))
        XCTAssertEqual(CoachSafetyGate.evaluate("We binge-watched the whole season last night."), .ordinary, "A TV binge is not a disclosure")
        XCTAssertEqual(CoachSafetyGate.evaluate("I binge eat after we argue."), .concern(.eating))
        XCTAssertEqual(CoachSafetyGate.evaluate("How do I add more fiber?"), .ordinary)
    }

    func test_declinedReplyIsHonestAndStillTakesCare() {
        let eating = CoachSafetyGate.declinedReply(concern: .eating)
        XCTAssertTrue(eating.contains("wouldn't process this message"))
        XCTAssertTrue(eating.contains("clinician or a therapist"))
        XCTAssertTrue(eating.contains("regular meals"), "Real help, not only a referral")
        XCTAssertTrue(eating.contains("ten minutes between the feeling and the food"))
        XCTAssertTrue(CoachSafetyGate.declinedReply(concern: .substance).contains("drink-free days"))
        XCTAssertTrue(CoachSafetyGate.declinedReply(concern: .strain).contains("hard stop on the workday"))
        XCTAssertTrue(eating.contains("?"), "Ends with a way back in")
        XCTAssertFalse(eating.lowercased().contains("rephras"))
        let mood = CoachSafetyGate.declinedReply(concern: .mood)
        XCTAssertTrue(mood.contains("988"))
        XCTAssertTrue(mood.contains("right this minute?"))
        let plain = CoachSafetyGate.declinedReply(concern: nil)
        XCTAssertFalse(plain.contains("988"))
        XCTAssertFalse(plain.contains("honesty"), "No disclosure was made; the wording must not imply one")
        XCTAssertTrue(plain.contains("declined the message"))
    }

    func test_escalationNeverHedgesAboutNotBeingAProfessional() {
        let crises = [
            "I want to kill myself",
            "I want to hurt someone",
            "I have chest pain when walking",
            "I make myself throw up after eating",
            "I have alcohol withdrawal"
        ]
        for crisis in crises {
            guard case .escalate(let message) = CoachSafetyGate.evaluate(crisis) else {
                return XCTFail("Expected escalation for \(crisis)")
            }
            let lowered = message.lowercased()
            XCTAssertFalse(lowered.contains("not an app"), crisis)
            XCTAssertFalse(lowered.contains("wellness coach"), crisis)
            XCTAssertFalse(lowered.contains("not a doctor"), crisis)
            XCTAssertTrue(message.hasPrefix(CoachSafetyGate.immediateHelpSentence), crisis)
        }
    }
}
