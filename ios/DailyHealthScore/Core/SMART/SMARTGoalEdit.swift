import Foundation

/// A detached edit. Only Save applies it to the latest stored goal.
/// No check-in state is copied back from the screen or from the model.
struct SMARTGoalEdit: Identifiable, Equatable {
    let id: UUID
    let original: SMARTGoal?
    var specificText: String
    var targetCount: Int
    var relevantTheme: SMARTRelevantTheme
    var endDate: Date
    var remindersEnabled: Bool
    var reminderHour: Int
    var reminderMinute: Int
    var reminderWeekdaysMask: Int
    var plan: SMARTGoalPlan
    var status: SMARTGoalStatus

    init(goal: SMARTGoal? = nil, id: UUID = UUID(), now: Date = Date()) {
        self.id = goal?.id ?? id
        original = goal
        specificText = goal?.specificText ?? ""
        targetCount = goal?.targetCount ?? 3
        relevantTheme = goal?.relevantTheme ?? .health
        endDate = goal?.endDate ?? SMARTGoalLogic.endDate(createdAt: now, days: 7)
        remindersEnabled = goal?.remindersEnabled ?? false
        reminderHour = goal?.reminderHour ?? 9
        reminderMinute = goal?.reminderMinute ?? 0
        let mask = goal?.reminderWeekdaysMask ?? 127
        reminderWeekdaysMask = mask == 0 ? 127 : mask
        plan = goal?.plan ?? .empty
        status = goal?.status ?? .active
    }

    var summary: String {
        let action = specificText.trimmingCharacters(in: .whitespacesAndNewlines)
        let times = targetCount == 1 ? "time" : "times"
        return "I will \(action) \(targetCount) \(times) by \(endDate.formatted(date: .abbreviated, time: .shortened)) because it supports \(relevantTheme.label.lowercased())."
    }

    func validationMessage(latest: SMARTGoal?, now: Date = Date()) -> String? {
        if original != nil {
            guard let latest, latest.id == id else { return "This goal was deleted. Close the editor to refresh your goals." }
            guard let original, Self.samePlan(original, latest) else {
                return "This goal was edited elsewhere. Close and reopen it to review the latest plan."
            }
        } else if latest != nil {
            return "This goal has already been saved. Close the editor to see it."
        }
        if specificText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "Describe the action you want to take."
        }
        if !(1...30).contains(targetCount) { return "Choose between 1 and 30 check-ins." }
        if let latest, targetCount < latest.filledCount {
            return "You have already recorded \(latest.filledCount) check-ins. Keep a target of at least that many to preserve your progress."
        }
        if original == nil && endDate <= now { return "Choose a future deadline." }
        // An unchanged deadline must remain exact, even for an ended goal.
        if endDate != original?.endDate && endDate <= now {
            return "Choose a future deadline, or keep the existing deadline."
        }
        if endDate != original?.endDate && endDate > SMARTGoalLogic.endDate(createdAt: now, days: 30) {
            return "Choose a deadline within the next 30 days."
        }
        if !(0...23).contains(reminderHour) || !(0...59).contains(reminderMinute) {
            return "Choose a valid reminder time."
        }
        if remindersEnabled && !(1...127).contains(reminderWeekdaysMask) {
            return "Choose at least one reminder day."
        }
        if let confidence = plan.confidence, !(1...10).contains(confidence) {
            return "Choose a confidence from 1 to 10, or leave it unset."
        }
        return nil
    }

    func build(latest: SMARTGoal?, now: Date = Date(), calendar: Calendar = .current) throws -> SMARTGoal {
        if let message = validationMessage(latest: latest, now: now) {
            throw SMARTGoalEditError.invalid(message)
        }
        var mask = latest?.filledMask ?? 0
        let validMask = (1 << targetCount) - 1
        if mask & ~validMask != 0 {
            // Circles have no timestamps or identities. Compact only when a
            // smaller target would otherwise discard a filled high-index circle.
            mask = (1 << (latest?.filledCount ?? 0)) - 1
        }
        let deadlineChanged = original?.endDate != endDate
        let days = max(1, calendar.dateComponents(
            [.day], from: calendar.startOfDay(for: now), to: calendar.startOfDay(for: endDate)
        ).day ?? 1)
        return SMARTGoal(
            id: id,
            specificText: specificText.trimmingCharacters(in: .whitespacesAndNewlines),
            targetCount: targetCount,
            relevantTheme: relevantTheme,
            timeWindowDays: deadlineChanged ? SMARTGoalLogic.clampedDays(days) : (latest?.timeWindowDays ?? days),
            endDate: endDate,
            createdAt: latest?.createdAt ?? now,
            generatedSummary: summary,
            filledMask: mask,
            status: resolvedStatus(now: now),
            remindersEnabled: remindersEnabled,
            reminderHour: reminderHour,
            reminderMinute: reminderMinute,
            reminderWeekdaysMask: reminderWeekdaysMask,
            plan: sanitizedPlan
        )
    }

    private var sanitizedPlan: SMARTGoalPlan {
        var plan = plan
        plan.personalReason = plan.personalReason.trimmingCharacters(in: .whitespacesAndNewlines)
        plan.cue = plan.cue.trimmingCharacters(in: .whitespacesAndNewlines)
        plan.expectedBarriers = plan.expectedBarriers.trimmingCharacters(in: .whitespacesAndNewlines)
        plan.fallbackAction = plan.fallbackAction.trimmingCharacters(in: .whitespacesAndNewlines)
        if !(0...23).contains(plan.reflectionHour) { plan.reflectionHour = 20 }
        if !(0...59).contains(plan.reflectionMinute) { plan.reflectionMinute = 0 }
        return plan
    }

    private func resolvedStatus(now: Date) -> SMARTGoalStatus {
        if endDate <= now { return .ended }
        if status == .paused { return .paused }
        return .active
    }

    /// Check-ins and automatic expiry may change while an editor is open.
    /// Changes to the actual plan require a fresh review.
    static func samePlan(_ lhs: SMARTGoal, _ rhs: SMARTGoal) -> Bool {
        lhs.id == rhs.id && lhs.specificText == rhs.specificText
            && lhs.targetCount == rhs.targetCount && lhs.relevantTheme == rhs.relevantTheme
            && lhs.endDate == rhs.endDate && lhs.createdAt == rhs.createdAt
            && lhs.remindersEnabled == rhs.remindersEnabled
            && lhs.reminderHour == rhs.reminderHour && lhs.reminderMinute == rhs.reminderMinute
            && lhs.reminderWeekdaysMask == rhs.reminderWeekdaysMask
            && lhs.plan == rhs.plan
    }
}

enum SMARTGoalEditError: LocalizedError {
    case invalid(String)
    var errorDescription: String? {
        switch self { case .invalid(let message): return message }
    }
}
