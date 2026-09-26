import SwiftData
import XCTest
@testable import DailyHealthScore

final class CoachMemoryFilesLogicTests: XCTestCase {
    func test_legacyCategoriesFileIntoSections() {
        XCTAssertEqual(CoachMemoryCategory.trigger.section, .patterns)
        XCTAssertEqual(CoachMemoryCategory.relationship.section, .people)
        XCTAssertEqual(CoachMemoryCategory.recovery.section, .body)
        XCTAssertEqual(CoachMemoryCategory.nutrition.section, .routines)
        XCTAssertEqual(CoachMemoryCategory.whatToAvoid.section, .coaching)
        XCTAssertEqual(CoachMemoryCategory.preference.section, .coaching)
        XCTAssertEqual(CoachMemoryCategory.identity.section, .aboutYou)
        XCTAssertEqual(CoachMemoryCategory.circumstance.section, .recent)
        XCTAssertEqual(CoachMemoryCategory(section: .recent), .checkIns)
        XCTAssertEqual(CoachMemoryCategory(section: .coaching), .helps)
        XCTAssertEqual(CoachMemoryCategory(section: .likes), .likes)
        // Storage keys stay stable across the rename.
        XCTAssertEqual(CoachMemorySection.coaching.rawValue, "helps")
        XCTAssertEqual(CoachMemorySection.recent.rawValue, "checkIns")
        XCTAssertEqual(CoachMemorySection(modelValue: "Patterns & triggers"), .patterns)
        XCTAssertEqual(CoachMemorySection(modelValue: "people"), .people)
        XCTAssertEqual(CoachMemorySection(modelValue: "coaching"), .coaching)
        XCTAssertEqual(CoachMemorySection(modelValue: "How to coach me"), .coaching)
        XCTAssertEqual(CoachMemorySection(modelValue: "likes"), .likes)
        XCTAssertEqual(CoachMemorySection(modelValue: "recent"), .recent)
        XCTAssertEqual(CoachMemorySection(modelValue: "checkIns"), .recent)
        XCTAssertEqual(CoachMemorySection(modelValue: "nonsense"), .aboutYou)
        XCTAssertEqual(CoachMemorySection.allCases.count, 9)
    }

    func test_memoryUpdateCarriesBasisAndLongerNotes() {
        let stated = CoachMemoryUpdate(operation: "add", section: "aboutYou", text: "Family medicine physician, outpatient.", replaces: "", basis: "stated")
        XCTAssertEqual(stated?.basis, .stated)
        XCTAssertEqual(stated?.basis.provenance, .coachRecorded)
        let inferred = CoachMemoryUpdate(operation: "add", section: "patterns", text: "Tends to withdraw when a steadying person leaves.", replaces: "", basis: "Inferred")
        XCTAssertEqual(inferred?.basis, .inferred)
        XCTAssertEqual(inferred?.basis.provenance, .coachNoted)
        let pattern = "Tends to withdraw and snack late after conflict at home, usually evenings; a ten-minute walk with his wife before anything else has helped him more than once (as of Sep 2026)."
        let long = CoachMemoryUpdate(operation: "add", section: "patterns", text: pattern, replaces: "")
        XCTAssertEqual(long?.text, pattern)
        XCTAssertEqual(CoachMemoryItem.maxContentLength, 240)
    }

    func test_memoryUpdateParsesLooseModelOutput() {
        let add = CoachMemoryUpdate(operation: "Add", section: "People", text: "Wife is **Sarah**; two kids.", replaces: "")
        XCTAssertEqual(add?.operation, .add)
        XCTAssertEqual(add?.section, .people)
        XCTAssertEqual(add?.text, "Wife is Sarah; two kids.")
        XCTAssertEqual(add?.basis, .stated)

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

    /// The intake asks toward whichever durable files are still empty; Recent is state.
    func test_emptySectionsFollowTheIntakeOrderAndSkipRecent() {
        XCTAssertEqual(
            CoachMemoryLogic.emptySections(in: []),
            [.aboutYou, .routines, .people, .likes, .body, .patterns, .coaching, .goals]
        )
        let items = [
            CoachMemoryItem(category: .people, content: "Wife is Maureen; sons Isaac, 14, and Caleb, 13.", provenance: .coachRecorded),
            CoachMemoryItem(category: .checkIns, content: "Mood: steady this week.", provenance: .coachRecorded)
        ]
        let empty = CoachMemoryLogic.emptySections(in: items)
        XCTAssertFalse(empty.contains(.people))
        XCTAssertFalse(empty.contains(.recent))
        XCTAssertEqual(empty.first, .aboutYou)
        XCTAssertEqual(empty.map(\.label).first, "About you")
    }

    /// The prompt block can be limited to a set of files.
    func test_promptBlockCanBeScopedToChosenFiles() {
        let items = [
            CoachMemoryItem(category: .people, content: "Wife is Maureen; sons Isaac, 14, and Caleb, 13.", provenance: .coachRecorded),
            CoachMemoryItem(category: .patterns, content: "Binge-eats after arguments with his wife.", provenance: .coachRecorded),
            CoachMemoryItem(category: .body, content: "Uses a CPAP for sleep apnea.", provenance: .coachRecorded),
            CoachMemoryItem(category: .likes, content: "Eats whole-food plant-based.", provenance: .coachRecorded)
        ]
        let some = CoachMemoryLogic.promptBlock(items: items, sections: [.aboutYou, .body, .likes])
        XCTAssertTrue(some.contains("CPAP"))
        XCTAssertTrue(some.contains("plant-based"))
        XCTAssertFalse(some.contains("Maureen"))
        XCTAssertFalse(some.contains("Binge"))
        let all = CoachMemoryLogic.promptBlock(items: items)
        XCTAssertTrue(all.contains("Maureen"))
        XCTAssertTrue(CoachMemoryLogic.promptBlock(items: [], sections: [.body]).contains("No notes in these files yet."))
    }

    func test_topicRetrievalReturnsRelevantNotesInsteadOfTheBiography() {
        let items = [
            CoachMemoryItem(category: .people, content: "Wife is Maureen; sons Isaac and Caleb live at home.", provenance: .coachRecorded),
            CoachMemoryItem(category: .patterns, content: "Conflict with his wife can make him assume negative intent.", provenance: .coachRecorded),
            CoachMemoryItem(category: .likes, content: "Likes Seven Sundays Wildberry Protein Oats.", provenance: .coachRecorded),
            CoachMemoryItem(category: .routines, content: "Uses an AI scribe to finish patient notes at work.", provenance: .coachRecorded),
            CoachMemoryItem(category: .routines, content: "Drives fifty minutes each way and listens to audiobooks.", provenance: .coachRecorded),
            CoachMemoryItem(category: .body, content: "Uses CPAP for sleep apnea.", provenance: .coachRecorded)
        ]

        let work = CoachMemoryLogic.promptBlock(items: items, relevantTo: "confidence with patients at work")
        XCTAssertTrue(work.contains("AI scribe"))
        XCTAssertFalse(work.contains("Maureen"))
        XCTAssertFalse(work.contains("Wildberry"))
        XCTAssertFalse(work.contains("CPAP"))
        XCTAssertFalse(work.contains("audiobooks"))

        let relationship = CoachMemoryLogic.promptBlock(items: items, relevantTo: "conflict with wife")
        XCTAssertTrue(relationship.contains("Maureen"))
        XCTAssertTrue(relationship.contains("negative intent"))
        XCTAssertFalse(relationship.contains("Wildberry"))

        let missing = CoachMemoryLogic.promptBlock(items: items, relevantTo: "swimming")
        XCTAssertEqual(missing, "No saved notes match this topic.")

        let notes = CoachMemoryLogic.matchingNotes(items: items, relevantTo: "conflict with wife")
        XCTAssertTrue(notes.contains("Maureen"))
        XCTAssertTrue(notes.contains("negative intent"))
        XCTAssertFalse(notes.contains("PEOPLE"))
        XCTAssertFalse(notes.contains("Write down"))
        XCTAssertEqual(
            CoachMemoryLogic.matchingNotes(items: items, relevantTo: "swimming"),
            "No saved notes match this topic."
        )
    }

    func test_cardNotesAreNewestDatedLinesWithoutFileHeadings() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let older = CoachMemoryItem(
            category: .people,
            content: "Wife is Maureen.",
            provenance: .userStated,
            createdAt: now.addingTimeInterval(-86_400 * 3)
        )
        let newer = CoachMemoryItem(
            category: .routines,
            content: "Clinic runs late on Thursdays.",
            provenance: .coachNoted,
            createdAt: now.addingTimeInterval(-3_600)
        )
        let notes = CoachMemoryLogic.cardNotes(items: [older, newer], at: now)
        let lines = notes.split(separator: "\n")
        XCTAssertEqual(lines.count, 2)
        XCTAssertTrue(lines[0].contains("Clinic runs late"))
        XCTAssertTrue(lines[0].contains("(inferred)"))
        XCTAssertTrue(lines[1].contains("Maureen"))
        XCTAssertTrue(lines[1].contains("(stated)"))
        XCTAssertFalse(notes.contains("PEOPLE"))
        XCTAssertFalse(notes.contains("ROUTINES"))
        XCTAssertEqual(CoachMemoryLogic.cardNotes(items: []), "No saved notes.")

        let extra = (0..<8).map { index in
            CoachMemoryItem(
                category: .checkIns,
                content: "Note \(index).",
                provenance: .userStated,
                createdAt: now.addingTimeInterval(TimeInterval(index))
            )
        }
        XCTAssertEqual(CoachMemoryLogic.cardNotes(items: extra, at: now.addingTimeInterval(100)).split(separator: "\n").count, 6)
    }

    func test_broadMemoryTopicCanDeliberatelyReturnAllNotes() {
        let items = [
            CoachMemoryItem(category: .people, content: "Wife is Maureen.", provenance: .coachRecorded),
            CoachMemoryItem(category: .likes, content: "Likes yoga.", provenance: .coachRecorded)
        ]
        let block = CoachMemoryLogic.promptBlock(items: items, relevantTo: "full profile")
        XCTAssertTrue(block.contains("Maureen"))
        XCTAssertTrue(block.contains("yoga"))
        XCTAssertEqual(CoachMemoryLogic.items(relevantTo: "this person", in: items), [])
    }

    /// A note comes from the person's words, never from the Coach's suggestion.
    func test_newNotesMustBeGroundedInThePersonsWords() {
        let spoken = "I've been doing better recently with not bringing work home. I'm using our AI scribe which is helping."
        let real = CoachMemoryUpdate(operation: "add", section: "routines", text: "Uses an AI scribe to finish notes at work as of September 2026.", replaces: "", basis: "stated")!
        let invented = CoachMemoryUpdate(operation: "add", section: "patterns", text: "Finds tracking food helpful for staying steady.", replaces: "", basis: "inferred")!
        let removal = CoachMemoryUpdate(operation: "remove", section: "routines", text: "", replaces: "Works Saturdays.", basis: "stated")!
        XCTAssertTrue(CoachMemoryLogic.isGrounded(real, inPersonsWords: spoken))
        XCTAssertFalse(CoachMemoryLogic.isGrounded(invented, inPersonsWords: spoken))
        XCTAssertTrue(CoachMemoryLogic.isGrounded(removal, inPersonsWords: spoken), "Removals need no grounding")
        let kids = CoachMemoryUpdate(operation: "add", section: "people", text: "Sons Isaac, 14, and Caleb, 13, as of September 2026.", replaces: "", basis: "stated")!
        XCTAssertTrue(CoachMemoryLogic.isGrounded(kids, inPersonsWords: "My two sons Isaac age 14 and Caleb age 13 live with us."))
    }

    /// A long disclosure is filed one sentence at a time.
    func test_extractorFilesEachSentenceOnItsOwn() {
        let message = "From a work standpoint, if I get a little behind, I tend to get a lot behind. From a healthy eating standpoint, I tend to binge-eat to deal with stress when my wife and I fight. My wife and I have started to try to pause and reflect rather than continuing to bicker."
        let items = CoachPhDMemoryExtractor.items(from: message)
        XCTAssertFalse(items.isEmpty)
        XCTAssertTrue(items.allSatisfy { !$0.content.contains("work standpoint") || !$0.content.contains("bicker") }, "No note carries the whole paragraph")
        XCTAssertTrue(items.contains { $0.content.contains("binge-eat") })
    }

    func test_promptBlockDatesEntriesAndSeparatesStatedFromInferred() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Chicago")!
        let now = calendar.date(from: DateComponents(year: 2026, month: 9, day: 20, hour: 12))!
        let sep6 = calendar.date(from: DateComponents(year: 2026, month: 9, day: 6, hour: 9))!
        let july = calendar.date(from: DateComponents(year: 2026, month: 7, day: 20, hour: 9))!
        let items = [
            CoachMemoryItem(category: .people, content: "Wife is Sarah.", provenance: .coachRecorded, createdAt: now),
            CoachMemoryItem(category: .patterns, content: "Seems to withdraw when a steadying person leaves.", provenance: .coachNoted, createdAt: now),
            CoachMemoryItem(category: .trigger, content: "I overeat when we argue.", provenance: .userStated, createdAt: now, confirmation: .confirmed),
            CoachMemoryItem(category: .checkIns, content: "Mood: depressed lately; late-night gaming is the hurdle.", provenance: .coachRecorded, createdAt: sep6),
            CoachMemoryItem(category: .checkIns, content: "Started evening walks with his wife.", provenance: .coachRecorded, createdAt: july)
        ]
        let block = CoachMemoryLogic.promptBlock(items: items, at: now, calendar: calendar)
        XCTAssertTrue(block.contains("PEOPLE:"))
        XCTAssertTrue(block.contains("- [Sep 20] Wife is Sarah. (stated)"))
        XCTAssertTrue(block.contains("PATTERNS & TRIGGERS:"))
        XCTAssertTrue(block.contains("- [Sep 20] Seems to withdraw when a steadying person leaves. (inferred)"))
        XCTAssertTrue(block.contains("- [Sep 20] I overeat when we argue. (stated)"))
        XCTAssertTrue(block.contains("RECENT (newest first"))
        XCTAssertTrue(block.contains("- [Sep 6] Mood: depressed lately; late-night gaming is the hurdle. (stated)"))
        XCTAssertTrue(block.contains("- [Jul 20] Started evening walks with his wife. (stated) (older)"))
        XCTAssertFalse(block.contains("Sep 6] Mood: depressed lately; late-night gaming is the hurdle. (stated) (older)"))
        XCTAssertFalse(block.contains("unconfirmed"))
        XCTAssertTrue(CoachMemoryLogic.promptBlock(items: []).contains("No notes yet"))
    }

    func test_entryListCarriesIdsForTheOnDevicePasses() {
        let item = CoachMemoryItem(category: .likes, content: "Seven Sundays Wild Berry Protein Oats.", provenance: .coachRecorded)
        let list = CoachMemoryLogic.entryList(items: [item])
        XCTAssertTrue(list.hasPrefix(String(item.id.uuidString.prefix(8))))
        XCTAssertTrue(list.contains("| likes |"))
        XCTAssertTrue(list.contains("| stated |"))
        XCTAssertEqual(CoachMemoryLogic.entryList(items: []), "None.")
    }

    func test_reviewOperationsParseAndValidate() {
        let refile = CoachFileReviewOperation(kind: "refile", id: "abcdef12", section: "people", text: "", basis: "")
        XCTAssertEqual(refile?.kind, .refile)
        XCTAssertEqual(refile?.section, .people)
        XCTAssertNil(CoachFileReviewOperation(kind: "refile", id: "abc", section: "people", text: "", basis: ""))
        let update = CoachFileReviewOperation(kind: "update", id: "ABCDEF12", section: "", text: "Isaac (Freshman as of Aug 2026).", basis: "")
        XCTAssertEqual(update?.kind, .update)
        XCTAssertEqual(update?.idPrefix, "abcdef12")
        XCTAssertNil(update?.section)
        let add = CoachFileReviewOperation(kind: "add", id: "", section: "patterns", text: "Tends to disengage after conflict; small tasks restore momentum.", basis: "inferred")
        XCTAssertEqual(add?.kind, .add)
        XCTAssertEqual(add?.basis, .inferred)
        XCTAssertNil(CoachFileReviewOperation(kind: "add", id: "", section: "", text: "Something", basis: ""))
        XCTAssertNil(CoachFileReviewOperation(kind: "explode", id: "abcdef12", section: "", text: "", basis: ""))
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

    func test_profileSourceChangesWhenTheDayOrAConfirmationChanges() {
        let entry = CoachMemoryFingerprint.ProfileSourceEntry(
            id: "abc",
            section: "body",
            stated: false,
            content: "Allergic to penicillin."
        )
        let inferred = CoachMemoryFingerprint.profileSource(generation: "2", day: "2026-09-23", entries: [entry])
        var confirmed = entry
        confirmed.stated = true
        let stated = CoachMemoryFingerprint.profileSource(generation: "2", day: "2026-09-23", entries: [confirmed])
        let nextDay = CoachMemoryFingerprint.profileSource(generation: "2", day: "2026-09-24", entries: [entry])
        XCTAssertTrue(inferred.hasPrefix("2\n2026-09-23\n"))
        XCTAssertTrue(inferred.contains("|inferred|"))
        XCTAssertTrue(stated.contains("|stated|"))
        XCTAssertNotEqual(inferred, stated)
        XCTAssertNotEqual(inferred, nextDay)
        XCTAssertNotEqual(CoachMemoryFingerprint.fingerprint(inferred), CoachMemoryFingerprint.fingerprint(stated))
        XCTAssertNotEqual(CoachMemoryFingerprint.fingerprint(inferred), CoachMemoryFingerprint.fingerprint(nextDay))
    }

    func test_compilerEntryListKeepsDurableNotesAheadOfALongRecentFile() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = calendar.date(from: DateComponents(year: 2026, month: 9, day: 23, hour: 15))!
        let allergy = CoachMemoryItem(
            category: .recovery,
            content: "Allergic to penicillin.",
            provenance: .userStated,
            createdAt: now,
            confirmation: .confirmed
        )
        let spouse = CoachMemoryItem(
            category: .people,
            content: "Wife is Sarah.",
            provenance: .userStated,
            createdAt: now,
            confirmation: .confirmed
        )
        var items = [allergy, spouse]
        for index in 0..<8 {
            items.append(CoachMemoryItem(
                category: .checkIns,
                content: "Recent note \(index) about a long clinic day, the drive home, and an audiobook.",
                provenance: .coachRecorded,
                createdAt: now.addingTimeInterval(Double(index))
            ))
        }
        let list = CoachMemoryLogic.compilerEntryList(items: items, at: now, calendar: calendar, characterBudget: 160)
        XCTAssertTrue(list.contains("Allergic to penicillin."))
        XCTAssertTrue(list.contains("Wife is Sarah."))
        XCTAssertFalse(list.contains("Recent note"))
        XCTAssertEqual(CoachMemoryLogic.compilerEntryList(items: [], at: now, calendar: calendar), "None.")
        let today = CoachMemoryLogic.compilerToday(now, calendar: calendar)
        XCTAssertTrue(today.contains("2026"))
        XCTAssertTrue(today.contains("Sep"))
        XCTAssertTrue(today.contains("23"))
    }

    func test_backgroundCompileKeepsAPassageOnlyForTheNotesItWasWrittenFrom() {
        let prompt = CoachCharter.backgroundCompilePrompt(
            entryList: "abc | body | Sep 1 | stated | Allergic to penicillin.",
            today: "Wed, Sep 23, 2026"
        )
        XCTAssertTrue(prompt.contains("Today is Wed, Sep 23, 2026."))
        XCTAssertTrue(prompt.contains("Write the background."))
        XCTAssertTrue(prompt.contains("Allergic to penicillin."))
        XCTAssertFalse(prompt.contains("Compile the profile"))

        let sentence = "Clinic days run long and notes pile up before lunch. "
        let stored = CoachCharter.backgroundToStore(
            compiled: String(repeating: sentence, count: 40),
            sourceUnchanged: true,
            notesAreEmpty: false
        )
        XCTAssertNotNil(stored)
        XCTAssertLessThanOrEqual(stored?.count ?? 0, CoachCharter.backgroundCharacterBudget)
        XCTAssertTrue(stored?.hasSuffix(".") == true)
        XCTAssertNil(CoachCharter.backgroundToStore(compiled: "   ", sourceUnchanged: true, notesAreEmpty: false))
        XCTAssertNil(CoachCharter.backgroundToStore(compiled: "Family physician.", sourceUnchanged: false, notesAreEmpty: false))
        XCTAssertEqual(
            CoachCharter.backgroundToStore(compiled: "Family physician.", sourceUnchanged: true, notesAreEmpty: true),
            ""
        )
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
        XCTAssertEqual(store.effectiveMemories.first?.provenance, .coachRecorded)

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

    func test_inferredNotesCanBeConfirmedOrRejected() {
        let store = makeStore()
        store.applyCoachUpdates(
            [CoachMemoryUpdate(operation: .add, section: .patterns, text: "Seems to withdraw when a steadying person leaves.", basis: .inferred)],
            threadID: nil,
            generationRevision: store.memoryRevision
        )
        let inferred = store.effectiveMemories[0]
        XCTAssertEqual(inferred.provenance, .coachNoted)
        XCTAssertFalse(inferred.provenance.isStated)
        XCTAssertTrue(store.promptMemoryBlock.contains("(inferred)"))

        store.confirmInference(inferred)
        let confirmed = store.effectiveMemories[0]
        XCTAssertEqual(confirmed.provenance, .userConfirmed)
        XCTAssertTrue(store.promptMemoryBlock.contains("(stated)"))
        XCTAssertFalse(store.promptMemoryBlock.contains("(inferred)"))
    }

    func test_reviewRefilesAndUndoMovesItBack() {
        let store = makeStore()
        store.applyCoachUpdates(
            [CoachMemoryUpdate(operation: .add, section: .goals, text: "Sons: Isaac (Freshman as of Aug 2026), Caleb (7th grade).")],
            threadID: nil,
            generationRevision: store.memoryRevision
        )
        let item = store.effectiveMemories[0]
        XCTAssertEqual(item.section, .goals)
        let prefix = String(item.id.uuidString.prefix(8))
        let applied = store.applyReview([
            CoachFileReviewOperation(kind: "refile", id: prefix, section: "people", text: "", basis: "")!
        ])
        XCTAssertEqual(applied.count, 1)
        XCTAssertEqual(applied.first?.kind, .refiled)
        XCTAssertEqual(store.effectiveMemories[0].section, .people)
        XCTAssertTrue(applied.first?.summaryLine.hasPrefix("Moved to People") == true)

        store.undo(applied[0])
        XCTAssertEqual(store.effectiveMemories[0].section, .goals)
        XCTAssertEqual(store.effectiveMemories[0].content, item.content)
    }

    func test_reviewCannotShrinkAStatedNoteButMayDateIt() {
        let store = makeStore()
        store.addNote(section: .people, content: "Isaac is a freshman.")
        let item = store.effectiveMemories[0]
        let prefix = String(item.id.uuidString.prefix(8))
        let shrink = store.applyReview([
            CoachFileReviewOperation(kind: "update", id: prefix, section: "", text: "Isaac.", basis: "")!
        ])
        XCTAssertTrue(shrink.isEmpty)
        let dated = store.applyReview([
            CoachFileReviewOperation(kind: "update", id: prefix, section: "", text: "Isaac is a freshman (as of Aug 2026).", basis: "")!
        ])
        XCTAssertEqual(dated.count, 1)
        XCTAssertEqual(store.effectiveMemories[0].content, "Isaac is a freshman (as of Aug 2026).")
        XCTAssertTrue(store.effectiveMemories[0].provenance.isStated)
        XCTAssertTrue(store.applyReview([
            CoachFileReviewOperation(kind: "retire", id: String(store.effectiveMemories[0].id.uuidString.prefix(8)), section: "", text: "", basis: "")!
        ]).isEmpty, "A stated note outside Recent is never retired by housekeeping")
    }

    func test_compiledProfileIsInvalidatedWhenEntriesChange() {
        let store = makeStore()
        XCTAssertFalse(store.needsProfileCompile)
        store.addNote(section: .aboutYou, content: "Family medicine physician, outpatient.")
        XCTAssertTrue(store.needsProfileCompile)
        XCTAssertEqual(store.compiledProfile, "")
        store.saveCompiledProfile("About you: Family medicine physician, outpatient.")
        XCTAssertFalse(store.needsProfileCompile)
        XCTAssertEqual(store.compiledProfile, "About you: Family medicine physician, outpatient.")
        store.addNote(section: .likes, content: "Oatmeal for breakfast.")
        XCTAssertTrue(store.needsProfileCompile)
        XCTAssertEqual(store.compiledProfile, "", "A stale profile must not reach the prompt")
    }

    func test_confirmingAnInferenceInvalidatesTheCompiledBackground() {
        let store = makeStore()
        let added = store.applyCoachUpdates(
            [CoachMemoryUpdate(
                operation: .add,
                section: .patterns,
                text: "Seems to withdraw when Sarah travels.",
                basis: .inferred
            )],
            threadID: nil,
            generationRevision: store.memoryRevision
        )
        XCTAssertEqual(added.count, 1)
        XCTAssertFalse(store.effectiveMemories[0].provenance.isStated)
        store.saveCompiledProfile("He seems to withdraw when Sarah travels.")
        XCTAssertFalse(store.needsProfileCompile)
        store.confirmInference(store.effectiveMemories[0])
        XCTAssertTrue(store.effectiveMemories[0].provenance.isStated)
        XCTAssertTrue(store.needsProfileCompile)
        XCTAssertEqual(store.compiledProfile, "")
    }

    func test_deletingTheLastNoteDiscardsTheCompiledBackground() {
        let store = makeStore()
        store.addNote(section: .aboutYou, content: "Family medicine physician, outpatient.")
        store.saveCompiledProfile("Outpatient family physician.")
        store.delete(store.effectiveMemories[0])
        XCTAssertEqual(store.compiledProfile, "")
        store.discardCompiledProfileIfNotesAreGone()
        XCTAssertFalse(store.needsProfileCompile)
        XCTAssertEqual(store.compiledProfile, "")
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
