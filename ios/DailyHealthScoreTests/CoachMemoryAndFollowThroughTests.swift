import SwiftData
import XCTest
@testable import DailyHealthScore

final class CoachMemoryLogicTests: XCTestCase {
    func test_expiredMemoriesDoNotReturnThroughPromptOrEffectiveSet() {
        let expired = CoachMemoryItem(
            category: .circumstance,
            content: "Traveling this week",
            provenance: .legacyCoachNotes,
            createdAt: CoachTestFixtures.now.addingTimeInterval(-20 * 86_400),
            expiresAt: CoachTestFixtures.now.addingTimeInterval(-1),
            confirmation: .unconfirmed,
            isTemporary: true
        )
        XCTAssertFalse(expired.isEffective(at: CoachTestFixtures.now))
        let prompt = CoachMemoryLogic.promptBlock(items: [expired], at: CoachTestFixtures.now)
        XCTAssertFalse(prompt.contains("Traveling this week"))
    }

    func test_deletedMemoriesDoNotReturnAndAreTombstoned() {
        let live = CoachMemoryItem(
            category: .constraint,
            content: "Traveling this week",
            provenance: .userStated,
            confirmation: .confirmed
        )
        var deleted = live
        deleted.isDeleted = true
        XCTAssertFalse(deleted.isEffective())
        XCTAssertTrue(CoachMemoryLogic.effectiveItems([deleted]).isEmpty)
        XCTAssertTrue(
            CoachMemoryLogic.isTombstoned(
                content: "Traveling this week",
                tombstones: [live.contentFingerprint]
            )
        )
    }

    func test_confirmedConstraintOverridesOlderInterpretation() {
        let old = CoachMemoryItem(
            category: .constraint,
            content: "Cannot walk at all",
            provenance: .coachInterpretation,
            createdAt: CoachTestFixtures.now.addingTimeInterval(-1000)
        )
        let newer = CoachMemoryItem(
            category: .constraint,
            content: "Ankle is fine now",
            provenance: .userConfirmed,
            createdAt: CoachTestFixtures.now,
            lastConfirmedAt: CoachTestFixtures.now,
            confirmation: .confirmed
        )
        let prompt = CoachMemoryLogic.promptBlock(items: [old, newer])
        XCTAssertTrue(prompt.contains("Ankle is fine now"))
        XCTAssertFalse(prompt.contains("Cannot walk at all"))
    }

    func test_summarySanitizerDropsDeletedFacts() {
        let summary = "They like oats. Traveling this week. Keep evenings easy."
        let cleaned = CoachMemoryLogic.sanitizeSummary(summary, removing: ["Traveling this week"])
        XCTAssertFalse(cleaned.localizedCaseInsensitiveContains("Traveling this week"))
        XCTAssertTrue(cleaned.localizedCaseInsensitiveContains("oats"))
    }

    func test_legacyProfileNotesAreUnconfirmed() {
        var profile = CoachUserProfile()
        profile.constraints = "Shift work"
        let items = CoachMemoryLogic.legacyItems(from: profile, recordedAt: CoachTestFixtures.now)
        XCTAssertEqual(items.first?.provenance, .legacyCoachNotes)
        XCTAssertNotEqual(items.first?.provenance, .userConfirmed)
    }

    func test_modelInterpretationsStayUnconfirmed() {
        var profile = CoachUserProfile()
        profile.movementNotes = "Seems to dislike running"
        let items = CoachMemoryLogic.interpretationItems(from: profile, recordedAt: CoachTestFixtures.now)
        XCTAssertEqual(items.first?.provenance, .coachInterpretation)
        XCTAssertEqual(items.first?.confirmation, .needsReview)
    }
}

@MainActor
final class CoachMemoryStoreTests: XCTestCase {
    func test_lateModelOutputDoesNotRecreateADeletedMemory() {
        let container = AppDataSchema.makeContainer(inMemory: true)
        let store = CoachMemoryStore(modelContext: ModelContext(container))
        let item = CoachMemoryItem(
            category: .constraint,
            content: "Knee injury this week",
            provenance: .userStated,
            confirmation: .confirmed,
            isTemporary: true
        )
        store.save(item)
        store.delete(item)
        let revision = store.memoryRevision
        var incoming = CoachUserProfile()
        incoming.constraints = "Knee injury this week"
        XCTAssertFalse(store.ingestModelProfileUpdate(incoming, generationRevision: revision))
        XCTAssertTrue(store.effectiveMemories.isEmpty)
        XCTAssertFalse(store.promptMemoryBlock.contains("Knee injury this week"))
    }

    func test_appendingAChatTurnDoesNotBumpMemoryRevision() {
        let store = CoachMemoryStore(modelContext: ModelContext(AppDataSchema.makeContainer(inMemory: true)))
        let before = store.memoryRevision
        store.append(CoachChatTurn(role: .user, text: "What are easy ways to hit my fiber goal?"))
        XCTAssertEqual(store.memoryRevision, before)
        XCTAssertEqual(store.turns.last?.text, "What are easy ways to hit my fiber goal?")
    }

    func test_clearAllMemoryLeavesHealthAndGoalsUntouched() {
        let container = AppDataSchema.makeContainer(inMemory: true)
        let context = ModelContext(container)
        let memory = CoachMemoryStore(modelContext: context)
        let goals = SMARTGoalStore(modelContext: context)
        goals.save(CoachTestFixtures.goal())
        memory.append(CoachChatTurn(role: .user, text: "hello"))
        memory.clearAllMemory()
        XCTAssertTrue(memory.turns.isEmpty)
        XCTAssertFalse(goals.goals.isEmpty)
    }
}

final class CoachFocusContextTests: XCTestCase {
    func test_historicalContextKeepsTheSelectedPeriod() {
        let record = DailyRecord(
            date: "2026-08-01",
            sleepHours: 7.5,
            fiberGrams: 40,
            exerciseMinutes: 30,
            sleepHrvSDNNMs: nil,
            sleepGoal: .sevenHalf,
            fiberGoal: .forty,
            sleepScore: 4,
            fiberScore: 4,
            exerciseScore: 2,
            totalScore: 10,
            sleepPercent: 1,
            fiberPercent: 1,
            exercisePercent: 1,
            primaryFocus: .maintain,
            suggestion: "",
            suggestionPhase: .day,
            createdAt: Date(timeIntervalSince1970: 0),
            updatedAt: Date(timeIntervalSince1970: 0)
        )
        let focus = CoachFocusContextBuilder.day(record, dateKey: "2026-08-01", todayKey: "2026-09-10")
        XCTAssertTrue(focus.isHistorical)
        XCTAssertTrue(focus.promptBlock.contains("2026"))
        XCTAssertTrue(focus.promptBlock.contains("not today") || focus.promptBlock.contains("historical") || focus.promptBlock.contains("Do not silently switch"))
        XCTAssertFalse(focus.promptBlock.contains("September 10") && focus.valueSummary.contains("today's"))
    }

    func test_missingHealthDataIsNotZeroActivity() {
        let record = DailyRecord(
            date: "2026-09-10",
            sleepHours: 0,
            fiberGrams: 0,
            exerciseMinutes: 0,
            sleepHrvSDNNMs: nil,
            sleepGoal: .sevenHalf,
            fiberGoal: .forty,
            sleepScore: 0,
            fiberScore: 0,
            exerciseScore: 0,
            totalScore: 0,
            sleepPercent: 0,
            fiberPercent: 0,
            exercisePercent: 0,
            primaryFocus: .sleep,
            suggestion: "",
            suggestionPhase: .day,
            createdAt: Date(timeIntervalSince1970: 0),
            updatedAt: Date(timeIntervalSince1970: 0)
        )
        let focus = CoachFocusContextBuilder.metric(.sleep, record: record, nowKey: "2026-09-10")
        XCTAssertTrue(focus.missingData.localizedCaseInsensitiveContains("unlogged"))
        XCTAssertTrue(focus.valueSummary.contains("NO DATA"))
        XCTAssertFalse(focus.missingData.contains("zero sleep"))
    }
}

final class SMARTFollowThroughLogicTests: XCTestCase {
    func test_quietHoursAndFrequencyLimits() {
        var settings = SMARTFollowThroughSettings.default
        settings.quietHoursEnabled = true
        settings.quietHoursStartHour = 21
        settings.quietHoursEndHour = 7
        let calendar = Calendar(identifier: .gregorian)
        var components = DateComponents(year: 2026, month: 9, day: 10, hour: 22, minute: 0)
        components.calendar = calendar
        let night = calendar.date(from: components)!
        XCTAssertTrue(SMARTFollowThroughLogic.isWithinQuietHours(night, settings: settings, calendar: calendar))
        let allowed = SMARTFollowThroughLogic.nextAllowedFireDate(from: night, settings: settings, calendar: calendar)
        XCTAssertFalse(SMARTFollowThroughLogic.isWithinQuietHours(allowed, settings: settings, calendar: calendar))

        var plan = SMARTGoalPlan()
        plan.followThroughEnabled = true
        let goal = CoachTestFixtures.goal(plan: plan, endDate: CoachTestFixtures.now.addingTimeInterval(10 * 86_400))
        let alreadyReminded = CoachFollowThroughState(
            goalId: goal.id,
            lastReminderAt: CoachTestFixtures.now
        )
        let none = SMARTFollowThroughLogic.decisions(
            goals: [goal],
            activitiesByGoal: [:],
            states: [goal.id: alreadyReminded],
            settings: settings,
            now: CoachTestFixtures.now,
            calendar: calendar
        )
        XCTAssertFalse(none.contains { $0.kind == .checkInReminder })
    }

    func test_pausedCompleteExpiredAndDeletedGoalsDoNotNotify() {
        var plan = SMARTGoalPlan()
        plan.followThroughEnabled = true
        let paused = CoachTestFixtures.goal(status: .paused, plan: plan)
        let ended = CoachTestFixtures.goal(status: .ended, endDate: CoachTestFixtures.now.addingTimeInterval(-100), plan: plan)
        var complete = CoachTestFixtures.goal(target: 1, mask: 1, plan: plan)
        complete.filledMask = 1
        let decisions = SMARTFollowThroughLogic.decisions(
            goals: [paused, ended, complete],
            activitiesByGoal: [:],
            states: [:],
            settings: .default,
            now: CoachTestFixtures.now
        )
        XCTAssertTrue(decisions.isEmpty)
    }

    func test_missingCheckInDoesNotCreateAMissedActionNotification() {
        var plan = SMARTGoalPlan()
        plan.followThroughEnabled = true
        let goal = CoachTestFixtures.goal(plan: plan)
        let decisions = SMARTFollowThroughLogic.decisions(
            goals: [goal],
            activitiesByGoal: [:],
            states: [:],
            settings: .default,
            now: CoachTestFixtures.now
        )
        if let reminder = decisions.first(where: { $0.kind == .checkInReminder }) {
            XCTAssertTrue(reminder.body.contains("does not mean you missed"))
        }
    }
}
