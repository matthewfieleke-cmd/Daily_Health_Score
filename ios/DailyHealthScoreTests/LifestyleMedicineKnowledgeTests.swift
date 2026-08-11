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

    func test_retrievesConcreteMealContentForFoodQuestions() {
        let entries = LifestyleMedicineKnowledge.retrieve(query: "what should I have for breakfast?")
        XCTAssertTrue(entries.contains { $0.id == "meal-building" })
    }

    func test_retrievesComparisonContentForWalkingVersusRunning() {
        let entries = LifestyleMedicineKnowledge.retrieve(query: "what is better? walking or running?")
        XCTAssertTrue(entries.contains { $0.id == "walking-vs-running" })
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

    /// A tight budget on the smaller context window must still yield a usable
    /// fragment rather than nothing, which would leave the model improvising.
    func test_oversizedEntryIsTruncatedRatherThanDropped() {
        let block = LifestyleMedicineKnowledge.promptBlock(
            query: "are seed oils bad",
            limit: 4,
            characterBudget: 200
        )
        XCTAssertFalse(block.isEmpty)
        XCTAssertLessThanOrEqual(block.count, 200)
    }

    func test_commonWellnessQuestionsAllRetrieveSomething() {
        let questions = [
            "are seed oils inflammatory", "should i take creatine", "is diet soda bad",
            "do i need a multivitamin", "are eggs bad for cholesterol", "is soy bad for men",
            "should i eat organic", "does spot reduction work for belly fat",
            "should i stretch before i work out", "how many steps should i take",
            "what lowers blood pressure", "what is a good a1c", "is sauna good for you",
            "how do i eat healthy on a budget", "i work night shift and can't sleep",
            "my knee hurts when i walk", "what about menopause and sleep",
            "is melatonin safe", "do probiotics work", "is red meat bad",
            "is gluten bad for you", "does keto work", "why is my metabolism slow",
            "is it bad to eat late at night", "should i do hiit or steady cardio"
        ]
        for question in questions {
            XCTAssertFalse(
                LifestyleMedicineKnowledge.retrieve(query: question).isEmpty,
                "no reference material for: \(question)"
            )
        }
    }

    func test_relatedMapPointsAtRealEntries() {
        let ids = Set(LifestyleMedicineKnowledge.all.map(\.id))
        for (source, targets) in LifestyleMedicineKnowledge.relatedIds {
            XCTAssertTrue(ids.contains(source), "unknown related source \(source)")
            for target in targets {
                XCTAssertTrue(ids.contains(target), "unknown related target \(target) from \(source)")
            }
        }
    }

    /// Keyword matching only finds words the user said. A real answer about seed
    /// oils needs the refining and cooking material nobody thinks to ask about.
    func test_retrievalPullsInAdjacentMaterial() {
        let entries = LifestyleMedicineKnowledge.retrieve(query: "are seed oils bad for me", limit: 6)
        let ids = entries.map(\.id)
        XCTAssertEqual(ids.first, "seed-oils")
        XCTAssertTrue(ids.contains("cooking-oils"))
        XCTAssertTrue(ids.contains("ultra-processed"))
    }

    func test_expansionNeverPrecedesADirectMatch() {
        let entries = LifestyleMedicineKnowledge.retrieve(query: "how much fiber should I eat", limit: 4)
        XCTAssertEqual(entries.first?.topic, .fiber)
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
