import Combine
import Foundation
import SwiftData

@MainActor
final class SMARTGoalStore: ObservableObject {
    private enum Keys {
        static let schemaVersion = "dhs.smartGoals.schemaVersion"
    }

    private static let currentSchemaVersion = 1

    private let modelContext: ModelContext
    @Published private(set) var goals: [SMARTGoal] = []
    var onChange: (() -> Void)?
    private var reminderTasks: [UUID: Task<Void, Never>] = [:]

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        resetStoredGoalsForSchemaChangeIfNeeded()
        reload()
        refreshEndedStatus()
    }

    func reload() {
        let descriptor = FetchDescriptor<SMARTGoalEntity>(
            sortBy: [SortDescriptor(\.endDate, order: .forward)]
        )
        let entities = (try? modelContext.fetch(descriptor)) ?? []
        goals = entities.map { $0.toSMARTGoal() }
        onChange?()
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
        updateReminder(for: goal)
        return goal
    }

    private func updateReminder(for goal: SMARTGoal) {
        let previous = reminderTasks[goal.id]
        previous?.cancel()
        reminderTasks[goal.id] = Task {
            // Serialize changes for this goal so an old in-flight request cannot
            // restore an outdated reminder after an edit or a completion.
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

    /// Watch check-in: fill the next empty circle on the live goal, then persist.
    /// A missing, ended, or already-complete goal is a no-op.
    func fillNextEmpty(on goalId: UUID) {
        guard var goal = goals.first(where: { $0.id == goalId }) else { return }
        guard !goal.isExpired else { return }
        guard goal.fillNextEmpty() else { return }
        guard (try? persist(goal)) != nil else { return }
        updateReminder(for: goal)
    }

    private func persist(_ goal: SMARTGoal) throws {
        let id = goal.id
        let descriptor = FetchDescriptor<SMARTGoalEntity>(
            predicate: #Predicate { $0.id == id }
        )
        if let existing = try modelContext.fetch(descriptor).first {
            existing.apply(goal)
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

    func delete(id: UUID) {
        let descriptor = FetchDescriptor<SMARTGoalEntity>(
            predicate: #Predicate { $0.id == id }
        )
        if let entity = try? modelContext.fetch(descriptor).first {
            modelContext.delete(entity)
            try? modelContext.save()
        }
        cancelReminder(for: id)
        reload()
    }

    func refreshEndedStatus() {
        var changed = false
        let now = Date()
        let descriptor = FetchDescriptor<SMARTGoalEntity>()
        guard let entities = try? modelContext.fetch(descriptor) else { return }
        for entity in entities {
            if entity.statusRaw == SMARTGoalStatus.active.rawValue,
               entity.endDate < now,
               entity.filledMask < fullMask(for: entity.targetCount) {
                entity.statusRaw = SMARTGoalStatus.ended.rawValue
                changed = true
                cancelReminder(for: entity.id)
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
            reminderWeekdaysMask: goal.reminderWeekdaysMask
        )
        // Keep the previous attempt so the coach can reflect on its recorded
        // outcome. A renewal starts a separate goal with a new identity.
        var previous = goal
        previous.status = .ended
        save(previous)
        save(clone)
    }

    func completeAndRemove(id: UUID) {
        SMARTNotificationService.cancelReminders(for: id)
        delete(id: id)
    }

    private func fullMask(for count: Int) -> Int {
        count <= 0 ? 0 : (1 << count) - 1
    }

    private func resetStoredGoalsForSchemaChangeIfNeeded() {
        guard UserDefaults.standard.integer(forKey: Keys.schemaVersion) != Self.currentSchemaVersion else {
            return
        }

        let all = (try? modelContext.fetch(FetchDescriptor<SMARTGoalEntity>())) ?? []
        for entity in all {
            SMARTNotificationService.cancelReminders(for: entity.id)
            modelContext.delete(entity)
        }
        try? modelContext.save()
        UserDefaults.standard.set(Self.currentSchemaVersion, forKey: Keys.schemaVersion)
    }
}
