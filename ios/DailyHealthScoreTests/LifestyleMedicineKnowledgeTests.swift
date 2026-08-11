import XCTest
@testable import DailyHealthScore

final class LifestyleMedicineKnowledgeTests: XCTestCase {
    func test_libraryCoversEveryTopic() {
        let covered = Set(LifestyleMedicineKnowledge.all.map(\.topic))
        for topic in CoachKnowledgeTopic.allCases {
            XCTAssertTrue(covered.contains(topic), "Missing knowledge for \(topic.rawValue)")
        }
    }

    func test_entryIdsAreUnique() {
        let ids = LifestyleMedicineKnowledge.all.map(\.id)
        XCTAssertEqual(ids.count, Set(ids).count)
    }

    func test_retrievesVegetableQuestionWithVarietyAnswer() {
        let entries = LifestyleMedicineKnowledge.retrieve(query: "what is the healthiest vegetable?")
        XCTAssertTrue(entries.contains { $0.id == "vegetable-variety" })
    }

    func test_retrievesFiberFoodsForFiberQuestions() {
        let entries = LifestyleMedicineKnowledge.retrieve(query: "what are high fiber foods with beans?")
        XCTAssertTrue(entries.contains { $0.id == "fiber-foods" })
    }

    func test_retrievesSleepGuidanceForSleepQuestions() {
        let entries = LifestyleMedicineKnowledge.retrieve(query: "how much sleep should I get tonight?")
        XCTAssertTrue(entries.contains { $0.id == "sleep-duration" })
    }

    func test_promptBlockRespectsCharacterBudget() {
        let block = LifestyleMedicineKnowledge.promptBlock(
            query: "fiber sleep exercise stress habit",
            limit: 6,
            characterBudget: 600
        )
        XCTAssertLessThanOrEqual(block.count, 600)
    }

    func test_unmatchedQueryReturnsNoNoise() {
        let entries = LifestyleMedicineKnowledge.retrieve(query: "zzzz qqqq")
        XCTAssertTrue(entries.isEmpty)
    }

    func test_focusTopicMappingIsPopulated() {
        XCTAssertFalse(LifestyleMedicineKnowledge.topics(for: .fiber).isEmpty)
        XCTAssertFalse(LifestyleMedicineKnowledge.topics(for: .maintain).isEmpty)
    }
}

final class CoachSafetyGateTests: XCTestCase {
    func test_ordinaryMessagesPassThrough() {
        XCTAssertEqual(CoachSafetyGate.evaluate("How do I add more fiber?"), .ordinary)
    }

    func test_selfHarmEscalatesDeterministically() {
        guard case .escalate(let message) = CoachSafetyGate.evaluate("I want to kill myself") else {
            return XCTFail("Expected escalation")
        }
        XCTAssertTrue(message.contains("988"))
    }

    func test_chestPainEscalates() {
        guard case .escalate(let message) = CoachSafetyGate.evaluate("I have chest pain when walking") else {
            return XCTFail("Expected escalation")
        }
        XCTAssertTrue(message.lowercased().contains("emergency"))
    }

    func test_disorderedEatingEscalates() {
        guard case .escalate = CoachSafetyGate.evaluate("I make myself throw up after eating") else {
            return XCTFail("Expected escalation")
        }
    }
}
