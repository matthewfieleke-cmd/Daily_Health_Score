import Combine
import Foundation
import SwiftData

@MainActor
final class SMARTGoalStore: ObservableObject {
    private let modelContext: ModelContext
    @Published private(set) var goals: [SMARTGoal] = []
    @Published private(set) var activities: [SMARTGoalActivity] = []
    var onChange: (() -> Void)?
    private var reminderTasks: [UUID: Task<Void, Never>] = [:]

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        migrateStoredGoalsIfNeeded()
        reload()
        refreshEndedStatus()
    }

    func reload() {
        let descriptor = FetchDescriptor<SMARTGoalEntity>(
            sortBy: [SortDescriptor(\.endDate, order: .forward)]
        )
        let entities = (try? modelContext.fetch(descriptor)) ?? []
        let activityEntities = (try? modelContext.fetch(FetchDescriptor<SMARTGoalActivityEntity>())) ?? []
        activities = activityEntities.compactMap { $0.toActivity() }
        let byGoal = Dictionary(grouping: activities, by: \.goalId)
        goals = entities.map { entity in
            var goal = entity.toSMARTGoal()
            let events = byGoal[entity.id] ?? []
            if !events.isEmpty {
                goal.filledMask = SMARTGoalActivityLogic.filledMask(
                    from: events,
                    targetCount: goal.targetCount
                )
            }
            return goal
        }
        onChange?()
    }

    func activities(for goalId: UUID) -> [SMARTGoalActivity] {
        activities
            .filter { $0.goalId == goalId }
            .sorted { $0.recordedAt < $1.recordedAt }
    }

    func save(_ goal: SMARTGoal) {
        guard (try? persist(goal)) != nil else { return }
        updateReminder(for: goal)
    }

    @discardableResult
    func saveReviewed(_ edit: SMARTGoalEdit) throws -> SMARTGoal {
        let latest = goals.first { $0.id == edit.id }
        let goal = try edit.build(latest: latest)
        try persist(goal)
        if let latest, SMARTGoalActivityLogic.planChanged(from: latest, to: goal) {
            insertActivity(
                SMARTGoalActivity(
                    goalId: goal.id,
                    kind: .revision,
                    source: .userEntry,
                    occurredAt: Date(),
                    localDateKey: DateHelpers.localDateKey(),
                    revision: SMARTGoalRevisionSnapshot.from(latest),
                    note: "Saved plan revision. This is not a completed action."
                )
            )
        }
        syncProgressFromEvents(goalId: goal.id)
        reload()
        if let saved = goals.first(where: { $0.id == goal.id }) {
            updateReminder(for: saved)
            return saved
        }
        updateReminder(for: goal)
        return goal
    }

    @discardableResult
    func recordCheckIn(
        goalId: UUID,
        source: SMARTGoalActivitySource,
        occurredAt: Date?,
        clientEventId: String = "",
        countsTowardTarget: Bool = true,
        note: String = "",
        now: Date = Date(),
        timeZone: TimeZone = .current
    ) -> Bool {
        guard var goal = goals.first(where: { $0.id == goalId }) else { return false }
        guard goal.canLogCheckIn else { return false }
        if SMARTGoalActivityLogic.alreadyProcessed(clientEventId: clientEventId, in: activities) {
            return false
        }
        let localKey: String
        if let occurredAt {
            localKey = DateHelpers.localDateKey(from: occurredAt)
        } else {
            localKey = ""
        }
        let event = SMARTGoalActivity(
            goalId: goalId,
            kind: countsTowardTarget ? .checkIn : .fallbackCheckIn,
            source: source,
            occurredAt: occurredAt,
            recordedAt: now,
            timeZoneIdentifier: timeZone.identifier,
            localDateKey: localKey,
            clientEventId: clientEventId,
            countsTowardTarget: countsTowardTarget,
            note: note
        )
        insertActivity(event)
        syncProgressFromEvents(goalId: goalId)
        reload()
        if let updated = goals.first(where: { $0.id == goalId }) {
            goal = updated
            updateReminder(for: savedOrCurrent(goal))
        }
        return true
    }

    @discardableResult
    func recordFallback(goalId: UUID, source: SMARTGoalActivitySource = .iPhone, now: Date = Date()) -> Bool {
        guard let goal = goals.first(where: { $0.id == goalId }) else { return false }
        let fallback = goal.plan.fallbackAction.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !fallback.isEmpty, goal.canLogCheckIn else { return false }
        return recordCheckIn(
            goalId: goalId,
            source: source,
            occurredAt: now,
            countsTowardTarget: false,
            note: "Smaller fallback recorded: \(fallback). Not counted toward the accepted action.",
            now: now
        )
    }

    @discardableResult
    func undoCheckIn(goalId: UUID, visualIndex: Int, now: Date = Date()) -> Bool {
        guard let goal = goals.first(where: { $0.id == goalId }),
              goal.status == .active, !goal.isExpired else { return false }
        let checkIns = SMARTGoalActivityLogic.activeCheckIns(in: activities(for: goalId))
        guard visualIndex >= 0, visualIndex < checkIns.count else { return false }
        return undo(event: checkIns[visualIndex], now: now)
    }

    @discardableResult
    func undo(eventId: UUID, now: Date = Date()) -> Bool {
        guard let event = activities.first(where: { $0.id == eventId }) else { return false }
        return undo(event: event, now: now)
    }

    @discardableResult
    func correctOccurrence(eventId: UUID, occurredAt: Date, now: Date = Date()) -> Bool {
        guard var event = activities.first(where: { $0.id == eventId }) else { return false }
        guard event.kind == .checkIn || event.kind == .fallbackCheckIn else { return false }
        event.occurredAt = occurredAt
        event.localDateKey = DateHelpers.localDateKey(from: occurredAt)
        event.timeZoneIdentifier = TimeZone.current.identifier
        upsertActivity(event)
        insertActivity(
            SMARTGoalActivity(
                goalId: event.goalId,
                kind: .correction,
                source: .userEntry,
                occurredAt: occurredAt,
                recordedAt: now,
                localDateKey: event.localDateKey,
                relatedEventId: event.id,
                note: "User supplied the action date. Delivery or migration time is not the action time."
            )
        )
        syncProgressFromEvents(goalId: event.goalId)
        reload()
        return true
    }

    @discardableResult
    func addReflection(goalId: UUID, text: String, relatedEventId: UUID? = nil, now: Date = Date()) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, goals.contains(where: { $0.id == goalId }) else { return false }
        insertActivity(
            SMARTGoalActivity(
                goalId: goalId,
                kind: .reflection,
                source: .userEntry,
                occurredAt: now,
                recordedAt: now,
                localDateKey: DateHelpers.localDateKey(from: now),
                reflectionText: trimmed,
                relatedEventId: relatedEventId
            )
        )
        reload()
        return true
    }

    func applyWatchEvent(_ event: WatchCheckInEvent, receivedAt: Date = Date()) -> Bool {
        recordCheckIn(
            goalId: event.goalId,
            source: .watch,
            occurredAt: event.createdAt,
            clientEventId: event.eventId.uuidString,
            now: receivedAt
        )
    }

    /// Watch check-in: fill the next empty circle on the live goal, then persist.
    /// A missing, ended, or already-complete goal is a no-op.
    func fillNextEmpty(on goalId: UUID, source: SMARTGoalActivitySource = .iPhone) {
        _ = recordCheckIn(goalId: goalId, source: source, occurredAt: Date())
    }

    func setPaused(_ paused: Bool, id: UUID) {
        guard var goal = goals.first(where: { $0.id == id }) else { return }
        if paused {
            guard goal.status == .active else { return }
            goal.status = .paused
        } else if goal.status == .paused {
            goal.status = goal.endDate > Date() ? .active : .ended
        } else {
            return
        }
        save(goal)
    }

    func delete(id: UUID) {
        let descriptor = FetchDescriptor<SMARTGoalEntity>(
            predicate: #Predicate { $0.id == id }
        )
        if let entity = try? modelContext.fetch(descriptor).first {
            modelContext.delete(entity)
        }
        let activityDescriptor = FetchDescriptor<SMARTGoalActivityEntity>(
            predicate: #Predicate { $0.goalId == id }
        )
        let related = (try? modelContext.fetch(activityDescriptor)) ?? []
        for entity in related {
            modelContext.delete(entity)
        }
        try? modelContext.save()
        cancelReminder(for: id)
        reload()
    }

    func refreshEndedStatus() {
        var changed = false
        let now = Date()
        let descriptor = FetchDescriptor<SMARTGoalEntity>()
        guard let entities = try? modelContext.fetch(descriptor) else { return }
        for entity in entities {
            let target = entity.targetCount
            let events = activities.filter { $0.goalId == entity.id }
            let filled = SMARTGoalActivityLogic.netCheckInCount(in: events)
            let isComplete = filled >= target
            if entity.statusRaw == SMARTGoalStatus.active.rawValue
                || entity.statusRaw == SMARTGoalStatus.paused.rawValue {
                if entity.endDate < now, !isComplete {
                    entity.statusRaw = SMARTGoalStatus.ended.rawValue
                    changed = true
                    cancelReminder(for: entity.id)
                }
            }
        }
        if changed {
            try? modelContext.save()
            reload()
        }
    }

    func renew(cloning goal: SMARTGoal) {
        guard let goal = goals.first(where: { $0.id == goal.id }) else { return }
        let created = Date()
        let endDate = SMARTGoalLogic.endDate(createdAt: created, days: goal.timeWindowDays)
        let clone = SMARTGoal(
            id: UUID(),
            specificText: goal.specificText,
            targetCount: goal.targetCount,
            relevantTheme: goal.relevantTheme,
            timeWindowDays: goal.timeWindowDays,
            endDate: endDate,
            createdAt: created,
            generatedSummary: SMARTGoalLogic.buildSummary(
                specific: goal.specificText,
                targetCount: goal.targetCount,
                theme: goal.relevantTheme,
                timeWindowDays: goal.timeWindowDays,
                endDate: endDate
            ),
            filledMask: 0,
            status: .active,
            remindersEnabled: goal.remindersEnabled,
            reminderHour: goal.reminderHour,
            reminderMinute: goal.reminderMinute,
            reminderWeekdaysMask: goal.reminderWeekdaysMask,
            plan: goal.plan
        )
        var previous = goal
        previous.status = .ended
        save(previous)
        save(clone)
    }

    func completeAndRemove(id: UUID) {
        SMARTNotificationService.cancelReminders(for: id)
        delete(id: id)
    }

    func followThroughStates() -> [UUID: CoachFollowThroughState] {
        let entities = (try? modelContext.fetch(FetchDescriptor<CoachFollowThroughStateEntity>())) ?? []
        var states: [UUID: CoachFollowThroughState] = [:]
        for entity in entities {
            states[entity.goalId] = CoachFollowThroughState(entity: entity)
        }
        return states
    }

    func snoozeFollowThrough(goalId: UUID, minutes: Int, now: Date = Date()) {
        let entity = followThroughEntity(goalId)
        entity.snoozeUntil = now.addingTimeInterval(TimeInterval(minutes * 60))
        try? modelContext.save()
    }

    func dismissFollowThrough(goalId: UUID, dateKey: String = DateHelpers.localDateKey()) {
        let entity = followThroughEntity(goalId)
        entity.dismissedDateKey = dateKey
        try? modelContext.save()
    }

    func markFollowThrough(kind: SMARTFollowThroughKind, goalId: UUID, at date: Date = Date()) {
        let entity = followThroughEntity(goalId)
        switch kind {
        case .checkInReminder: entity.lastReminderAt = date
        case .reflection: entity.lastReflectionAt = date
        case .weeklyReview: entity.lastReviewAt = date
        }
        try? modelContext.save()
    }

    private func followThroughEntity(_ goalId: UUID) -> CoachFollowThroughStateEntity {
        let descriptor = FetchDescriptor<CoachFollowThroughStateEntity>(
            predicate: #Predicate { $0.goalId == goalId }
        )
        if let existing = try? modelContext.fetch(descriptor).first {
            return existing
        }
        let created = CoachFollowThroughStateEntity(goalId: goalId)
        modelContext.insert(created)
        try? modelContext.save()
        return created
    }

    // MARK: - Persistence

    private func persist(_ goal: SMARTGoal) throws {
        let id = goal.id
        let descriptor = FetchDescriptor<SMARTGoalEntity>(
            predicate: #Predicate { $0.id == id }
        )
        if let existing = try modelContext.fetch(descriptor).first {
            existing.apply(goal)
            existing.filledMask = SMARTGoalActivityLogic.filledMask(
                from: activities(for: id),
                targetCount: goal.targetCount
            )
        } else {
            modelContext.insert(SMARTGoalEntity(goal: goal))
        }
        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            throw error
        }
        reload()
    }

    private func insertActivity(_ activity: SMARTGoalActivity) {
        if SMARTGoalActivityLogic.alreadyProcessed(clientEventId: activity.clientEventId, in: activities) {
            return
        }
        modelContext.insert(SMARTGoalActivityEntity(activity: activity))
        try? modelContext.save()
        activities.append(activity)
    }

    private func upsertActivity(_ activity: SMARTGoalActivity) {
        let id = activity.id
        let descriptor = FetchDescriptor<SMARTGoalActivityEntity>(
            predicate: #Predicate { $0.id == id }
        )
        if let existing = try? modelContext.fetch(descriptor).first {
            existing.apply(activity)
        } else {
            modelContext.insert(SMARTGoalActivityEntity(activity: activity))
        }
        try? modelContext.save()
    }

    private func undo(event: SMARTGoalActivity, now: Date) -> Bool {
        guard event.kind == .checkIn || event.kind == .fallbackCheckIn else { return false }
        if SMARTGoalActivityLogic.undoneIDs(in: activities).contains(event.id) { return false }
        insertActivity(
            SMARTGoalActivity(
                goalId: event.goalId,
                kind: .undo,
                source: .userEntry,
                occurredAt: now,
                recordedAt: now,
                localDateKey: DateHelpers.localDateKey(from: now),
                relatedEventId: event.id,
                note: "Check-in undone. History is preserved."
            )
        )
        syncProgressFromEvents(goalId: event.goalId)
        reload()
        if let goal = goals.first(where: { $0.id == event.goalId }) {
            updateReminder(for: goal)
        }
        return true
    }

    private func syncProgressFromEvents(goalId: UUID) {
        let id = goalId
        let descriptor = FetchDescriptor<SMARTGoalEntity>(
            predicate: #Predicate { $0.id == id }
        )
        guard let entity = try? modelContext.fetch(descriptor).first else { return }
        let events = ((try? modelContext.fetch(FetchDescriptor<SMARTGoalActivityEntity>())) ?? [])
            .compactMap { $0.toActivity() }
            .filter { $0.goalId == goalId }
        entity.filledMask = SMARTGoalActivityLogic.filledMask(
            from: events,
            targetCount: entity.targetCount
        )
        try? modelContext.save()
    }

    private func savedOrCurrent(_ goal: SMARTGoal) -> SMARTGoal {
        goals.first(where: { $0.id == goal.id }) ?? goal
    }

    private func updateReminder(for goal: SMARTGoal) {
        let previous = reminderTasks[goal.id]
        previous?.cancel()
        reminderTasks[goal.id] = Task {
            await previous?.value
            guard !Task.isCancelled else { return }
            await SMARTNotificationService.scheduleReminder(for: goal)
        }
    }

    private func cancelReminder(for id: UUID) {
        let previous = reminderTasks[id]
        previous?.cancel()
        reminderTasks[id] = Task {
            await previous?.value
            SMARTNotificationService.cancelReminders(for: id)
        }
    }

    /// Version 2 keeps existing goals and writes undated events for old bitmask
    /// counts. Occurrence dates stay unknown unless the user later supplies them.
    private func migrateStoredGoalsIfNeeded() {
        let stored = UserDefaults.standard.integer(forKey: SMARTGoalSchema.defaultsKey)
        if stored == SMARTGoalSchema.currentVersion { return }

        let all = (try? modelContext.fetch(FetchDescriptor<SMARTGoalEntity>())) ?? []
        let existingEvents = (try? modelContext.fetch(FetchDescriptor<SMARTGoalActivityEntity>())) ?? []
        let goalsWithEvents = Set(existingEvents.map(\.goalId))
        let recordedAt = Date()
        for entity in all {
            if goalsWithEvents.contains(entity.id) { continue }
            let migrated = SMARTGoalActivityLogic.undatedCheckInsFromLegacyMask(
                mask: entity.filledMask,
                targetCount: entity.targetCount,
                goalId: entity.id,
                recordedAt: recordedAt
            )
            for activity in migrated {
                modelContext.insert(SMARTGoalActivityEntity(activity: activity))
            }
            entity.filledMask = SMARTGoalProgress.mask(
                filledCount: migrated.count,
                targetCount: entity.targetCount
            )
        }
        try? modelContext.save()
        UserDefaults.standard.set(SMARTGoalSchema.currentVersion, forKey: SMARTGoalSchema.defaultsKey)
    }
}
