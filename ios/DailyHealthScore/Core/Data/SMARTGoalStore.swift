import Combine
import Foundation
import SwiftData

@MainActor
final class SMARTGoalStore: ObservableObject {
    private let modelContext: ModelContext
    @Published private(set) var goals: [SMARTGoal] = []

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        reload()
        refreshEndedStatus()
    }

    func reload() {
        let descriptor = FetchDescriptor<SMARTGoalEntity>(
            sortBy: [SortDescriptor(\.endDate, order: .forward)]
        )
        let entities = (try? modelContext.fetch(descriptor)) ?? []
        goals = entities.map { $0.toSMARTGoal() }
    }

    func save(_ goal: SMARTGoal) {
        let id = goal.id
        let descriptor = FetchDescriptor<SMARTGoalEntity>(
            predicate: #Predicate { $0.id == id }
        )
        if let existing = try? modelContext.fetch(descriptor).first {
            existing.apply(goal)
        } else {
            modelContext.insert(SMARTGoalEntity(goal: goal))
        }
        try? modelContext.save()
        reload()
        Task { await SMARTNotificationService.scheduleReminder(for: goal) }
    }

    func delete(id: UUID) {
        let descriptor = FetchDescriptor<SMARTGoalEntity>(
            predicate: #Predicate { $0.id == id }
        )
        if let entity = try? modelContext.fetch(descriptor).first {
            modelContext.delete(entity)
            try? modelContext.save()
        }
        SMARTNotificationService.cancelReminders(for: id)
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
                SMARTNotificationService.cancelReminders(for: entity.id)
            }
        }
        if changed {
            try? modelContext.save()
            reload()
        }
    }

    func renew(cloning goal: SMARTGoal) {
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
        delete(id: goal.id)
        save(clone)
    }

    func completeAndRemove(id: UUID) {
        SMARTNotificationService.cancelReminders(for: id)
        delete(id: id)
    }

    private func fullMask(for count: Int) -> Int {
        count <= 0 ? 0 : (1 << count) - 1
    }
}
