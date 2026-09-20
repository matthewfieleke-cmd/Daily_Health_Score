import SwiftData
import XCTest
@testable import DailyHealthScore

final class CoachMemoryFilesLogicTests: XCTestCase {
    func test_legacyCategoriesFileIntoSections() {
        XCTAssertEqual(CoachMemoryCategory.trigger.section, .patterns)
        XCTAssertEqual(CoachMemoryCategory.relationship.section, .people)
        XCTAssertEqual(CoachMemoryCategory.recovery.section, .body)
        XCTAssertEqual(CoachMemoryCategory.nutrition.section, .routines)
        XCTAssertEqual(CoachMemoryCategory.whatToAvoid.section, .helps)
        XCTAssertEqual(CoachMemoryCategory.identity.section, .aboutYou)
        XCTAssertEqual(CoachMemoryCategory(section: .checkIns), .checkIns)
        XCTAssertEqual(CoachMemorySection(modelValue: "Patterns & triggers"), .patterns)
        XCTAssertEqual(CoachMemorySection(modelValue: "people"), .people)
        XCTAssertEqual(CoachMemorySection(modelValue: "nonsense"), .aboutYou)
    }

    func test_memoryUpdateParsesLooseModelOutput() {
        let add = CoachMemoryUpdate(operation: "Add", section: "People", text: "Wife is **Sarah**; two kids.", replaces: "")
        XCTAssertEqual(add?.operation, .add)
        XCTAssertEqual(add?.section, .people)
        XCTAssertEqual(add?.text, "Wife is Sarah; two kids.")

        let remove = CoachMemoryUpdate(operation: "delete", section: "body", text: "", replaces: "Sprained ankle")
        XCTAssertEqual(remove?.operation, .remove)
        XCTAssertEqual(remove?.replaces, "Sprained ankle")

        XCTAssertNil(CoachMemoryUpdate(operation: "add", section: "people", text: "hi", replaces: ""))
        XCTAssertNil(CoachMemoryUpdate(operation: "shout", section: "people", text: "Something long enough", replaces: ""))

        let long = String(repeating: "word ", count: 80)
        let clipped = CoachMemoryUpdate(operation: "add", section: "aboutYou", text: long, replaces: "")
        XCTAssertLessThanOrEqual(clipped?.text.count ?? 0, CoachMemoryItem.maxContentLength)
    }

    func test_matchFindsNotesByTextContainmentAndOverlap() {
        let items = [
            CoachMemoryItem(category: .people, content: "Wife is Sarah; two kids under ten.", provenance: .coachNoted),
            CoachMemoryItem(category: .patterns, content: "Overeats after arguments with his wife.", provenance: .userStated)
        ]
        XCTAssertEqual(CoachMemoryLogic.match("wife is sarah; two kids under ten.", in: items, section: .people)?.id, items[0].id)
        XCTAssertEqual(CoachMemoryLogic.match("Overeats after arguments", in: items, section: nil)?.id, items[1].id)
        XCTAssertEqual(CoachMemoryLogic.match("arguments with wife lead to overeating", in: items, section: .patterns)?.id, items[1].id)
        XCTAssertNil(CoachMemoryLogic.match("Runs marathons every spring", in: items, section: nil))
        XCTAssertNil(CoachMemoryLogic.match("hi", in: items, section: nil))
    }

    func test_hasEquivalentCatchesDuplicates() {
        let items = [CoachMemoryItem(category: .routines, content: "Works night shifts Tuesday through Thursday.", provenance: .coachNoted)]
        XCTAssertTrue(CoachMemoryLogic.hasEquivalent("works night shifts tuesday through thursday.", in: items))
        XCTAssertTrue(CoachMemoryLogic.hasEquivalent("Works night shifts Tuesday through Thursday", in: items))
        XCTAssertFalse(CoachMemoryLogic.hasEquivalent("Prefers morning workouts.", in: items))
    }

    func test_promptBlockGroupsByFileAndMarksWhatThePersonSaid() {
        let items = [
            CoachMemoryItem(category: .people, content: "Wife is Sarah.", provenance: .coachNoted),
            CoachMemoryItem(category: .trigger, content: "I overeat when we argue.", provenance: .userStated, confirmation: .confirmed)
        ]
        let block = CoachMemoryLogic.promptBlock(items: items)
        XCTAssertTrue(block.contains("PEOPLE:"))
        XCTAssertTrue(block.contains("PATTERNS & TRIGGERS:"))
        XCTAssertTrue(block.contains("- I overeat when we argue. (they said this)"))
        XCTAssertTrue(block.contains("- Wife is Sarah.\n") || block.hasSuffix("- Wife is Sarah."))
        XCTAssertFalse(block.contains("unconfirmed"))
        XCTAssertTrue(CoachMemoryLogic.promptBlock(items: []).contains("No notes yet"))
    }

    func test_coachNotesSurviveAConfirmedNoteInTheSameFile() {
        let confirmed = CoachMemoryItem(category: .people, content: "Wife is Sarah.", provenance: .userConfirmed, confirmation: .confirmed)
        let noted = CoachMemoryItem(category: .people, content: "Brother lives nearby.", provenance: .coachNoted)
        let oldGuess = CoachMemoryItem(category: .people, content: "Maybe married?", provenance: .coachInterpretation)
        let kept = CoachMemoryLogic.itemsByOverridingContradictions([confirmed, noted, oldGuess]).map(\.content)
        XCTAssertTrue(kept.contains("Wife is Sarah."))
        XCTAssertTrue(kept.contains("Brother lives nearby."))
        XCTAssertFalse(kept.contains("Maybe married?"))
    }
}

@MainActor
final class CoachMemoryFilesStoreTests: XCTestCase {
    private func makeStore() -> CoachMemoryStore {
        CoachMemoryStore(modelContext: ModelContext(AppDataSchema.makeContainer(inMemory: true)))
    }

    func test_coachAddsUpdatesAndRemovesNotesWithUndo() {
        let store = makeStore()
        let revision = store.memoryRevision
        let added = store.applyCoachUpdates(
            [CoachMemoryUpdate(operation: .add, section: .people, text: "Wife is Sarah.")],
            threadID: nil,
            generationRevision: revision
        )
        XCTAssertEqual(added.count, 1)
        XCTAssertEqual(added.first?.kind, .added)
        XCTAssertEqual(store.effectiveMemories.map(\.content), ["Wife is Sarah."])
        XCTAssertEqual(store.effectiveMemories.first?.provenance, .coachNoted)

        // Duplicates are dropped silently.
        XCTAssertTrue(store.applyCoachUpdates(
            [CoachMemoryUpdate(operation: .add, section: .people, text: "wife is sarah.")],
            threadID: nil,
            generationRevision: store.memoryRevision
        ).isEmpty)

        let updated = store.applyCoachUpdates(
            [CoachMemoryUpdate(operation: .update, section: .people, text: "Wife is Sarah; two kids.", replaces: "Wife is Sarah.")],
            threadID: nil,
            generationRevision: store.memoryRevision
        )
        XCTAssertEqual(updated.first?.kind, .updated)
        XCTAssertEqual(store.effectiveMemories.map(\.content), ["Wife is Sarah; two kids."])
        XCTAssertEqual(store.recentChanges.count, 2)

        store.undo(updated[0])
        XCTAssertEqual(store.effectiveMemories.map(\.content), ["Wife is Sarah."])
        XCTAssertEqual(store.recentChanges.count, 1)
        XCTAssertTrue(store.changes.first(where: { $0.id == updated[0].id })?.isUndone == true)

        let removed = store.applyCoachUpdates(
            [CoachMemoryUpdate(operation: .remove, section: .people, text: "", replaces: "Wife is Sarah.")],
            threadID: nil,
            generationRevision: store.memoryRevision
        )
        XCTAssertEqual(removed.first?.kind, .removed)
        XCTAssertTrue(store.effectiveMemories.isEmpty)

        store.undo(removed[0])
        XCTAssertEqual(store.effectiveMemories.map(\.content), ["Wife is Sarah."])
    }

    func test_undoneAddIsTombstonedSoTheCoachCannotRewriteIt() {
        let store = makeStore()
        let added = store.applyCoachUpdates(
            [CoachMemoryUpdate(operation: .add, section: .patterns, text: "Snacks late when anxious.")],
            threadID: nil,
            generationRevision: store.memoryRevision
        )
        store.undo(added[0])
        XCTAssertTrue(store.effectiveMemories.isEmpty)
        let again = store.applyCoachUpdates(
            [CoachMemoryUpdate(operation: .add, section: .patterns, text: "Snacks late when anxious.")],
            threadID: nil,
            generationRevision: store.memoryRevision
        )
        XCTAssertTrue(again.isEmpty)
        XCTAssertTrue(store.effectiveMemories.isEmpty)
    }

    func test_staleGenerationCannotWriteAfterAHandEdit() {
        let store = makeStore()
        let revision = store.memoryRevision
        store.addNote(section: .body, content: "Left knee is sore this week.")
        let item = store.effectiveMemories[0]
        store.delete(item)
        XCTAssertNotEqual(store.memoryRevision, revision)
        let applied = store.applyCoachUpdates(
            [CoachMemoryUpdate(operation: .add, section: .body, text: "Left knee is sore this week.")],
            threadID: nil,
            generationRevision: revision
        )
        XCTAssertTrue(applied.isEmpty)
        XCTAssertTrue(store.effectiveMemories.isEmpty)
    }

    func test_newChatIsCreatedOnFirstMessageOnly() {
        let store = makeStore()
        store.open(.newChat)
        XCTAssertNil(store.openThread)
        XCTAssertTrue(store.threads.isEmpty)
        XCTAssertTrue(store.visibleTurns.isEmpty)

        store.append(CoachChatTurn(role: .user, text: "My wife says I should set a smart goal for walking"))
        XCTAssertEqual(store.threads.count, 1)
        XCTAssertEqual(store.openThread?.title, "My wife says I should set")
        XCTAssertEqual(store.openThread?.messageCount, 1)
        XCTAssertTrue(store.openThread?.titleIsProvisional == true)
        XCTAssertEqual(store.turns.count, 1)

        store.append(CoachChatTurn(role: .coach, text: "**Good** instinct. What kind of walk?"))
        XCTAssertEqual(store.openThread?.messageCount, 2)
        XCTAssertEqual(store.openThread?.preview, "Good instinct. What kind of walk?")

        store.applyReplyMetadata(threadID: store.openThread!.id, title: "\"Walking Goal With Sarah\"", summary: "Wants a walking goal.", pillar: .activity)
        XCTAssertEqual(store.openThread?.title, "Walking Goal With Sarah")
        XCTAssertEqual(store.openThread?.pillar, .activity)
        XCTAssertEqual(store.openThread?.summary, "Wants a walking goal.")
        XCTAssertTrue(store.openThread?.titleIsProvisional == false)

        // A settled title stays put unless the topic moves.
        store.applyReplyMetadata(threadID: store.openThread!.id, title: "Something Else", summary: "", pillar: .activity)
        XCTAssertEqual(store.openThread?.title, "Walking Goal With Sarah")
        store.applyReplyMetadata(threadID: store.openThread!.id, title: "Argument With Sarah", summary: "", pillar: .relationships)
        XCTAssertEqual(store.openThread?.title, "Argument With Sarah")
    }

    func test_backingOutOfSeveralNewChatsLeavesNoRows() {
        let store = makeStore()
        store.open(.newChat)
        store.open(.chats)
        store.open(.newChat)
        store.open(.acquaint)
        store.open(.chats)
        XCTAssertTrue(store.threads.isEmpty)
    }

    func test_acquaintanceOpensWithTheCoachAndPersistsItsOpener() {
        let store = makeStore()
        XCTAssertTrue(store.needsAcquaintance)
        store.open(.acquaint)
        XCTAssertEqual(store.visibleTurns.count, 1)
        XCTAssertEqual(store.visibleTurns.first?.role, .coach)
        XCTAssertTrue(store.threads.isEmpty)

        store.append(CoachChatTurn(role: .user, text: "A good day starts slow."))
        XCTAssertEqual(store.threads.count, 1)
        XCTAssertEqual(store.openThread?.kind, .acquaintance)
        XCTAssertEqual(store.turns.count, 2)
        XCTAssertEqual(store.turns.first?.role, .coach)
        XCTAssertEqual(store.turns.first?.text, CoachAcquaintance.opener)
        XCTAssertFalse(store.needsAcquaintance)

        // Reopening finds the same chat instead of starting another.
        store.open(.chats)
        store.open(.acquaint)
        XCTAssertEqual(store.openThread?.kind, .acquaintance)
        XCTAssertEqual(store.threads.count, 1)
    }

    func test_replyToCheckInSeedsTheCardAndLinksBack() {
        let store = makeStore()
        let card = CoachCheckIn(kind: .morning, dateKey: "2026-09-19", healthLine: "You're at 6 of 10.", question: "What matters today?")
        store.saveCheckIn(card, key: "k")
        store.open(.replyToCheckIn)
        XCTAssertEqual(store.visibleTurns.first?.text, card.spokenText)
        XCTAssertNil(store.cachedCheckIn?.replyThreadID)

        store.append(CoachChatTurn(role: .user, text: "Getting the kids out the door calmly."))
        let thread = store.openThread
        XCTAssertEqual(thread?.kind, .checkInReply)
        XCTAssertEqual(store.cachedCheckIn?.replyThreadID, thread?.id)
        XCTAssertEqual(store.turns.count, 2)

        store.open(.chats)
        store.open(.replyToCheckIn)
        XCTAssertEqual(store.openThread?.id, thread?.id)

        store.deleteThread(thread!.id)
        XCTAssertNil(store.cachedCheckIn?.replyThreadID)
        XCTAssertTrue(store.threads.isEmpty)
    }

    func test_deletingChatsKeepsTheMemoryFiles() {
        let store = makeStore()
        store.open(.newChat)
        store.append(CoachChatTurn(role: .user, text: "I overeat when my wife and I argue."))
        store.applyCoachUpdates(
            [CoachMemoryUpdate(operation: .add, section: .patterns, text: "Overeats after arguments with his wife.")],
            threadID: store.openThread?.id,
            generationRevision: store.memoryRevision
        )
        XCTAssertEqual(store.threads.count, 1)
        XCTAssertEqual(store.effectiveMemories.count, 1)

        store.deleteAllChats()
        XCTAssertTrue(store.threads.isEmpty)
        XCTAssertTrue(store.allTurns.isEmpty)
        XCTAssertEqual(store.effectiveMemories.count, 1)
        XCTAssertNil(store.openThread)

        store.clearAllMemory()
        XCTAssertTrue(store.effectiveMemories.isEmpty)
    }

    func test_focusLaunchTagsThePillarAndKeepsContext() {
        let store = makeStore()
        let focus = CoachFocusContext(feature: .sleep, valueSummary: "Sleep: 6.1 h of a 7.5 h goal — BELOW GOAL by 1.4 h (81% of goal).")
        store.open(.focus(focus))
        store.append(CoachChatTurn(role: .user, text: "Why am I so tired?"))
        XCTAssertEqual(store.openThread?.pillar, .sleep)
        XCTAssertEqual(store.openThread?.title, "Sleep")
        XCTAssertTrue(store.openThread?.contextNote.contains("Sleep") == true)
    }
}
