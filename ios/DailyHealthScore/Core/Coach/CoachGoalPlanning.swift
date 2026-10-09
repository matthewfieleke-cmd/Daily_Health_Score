import Foundation

/// Model output becomes a detached, validated proposal. It cannot write goals.
struct CoachGoalProposal: Identifiable, Equatable {
    let id: UUID
    var edit: SMARTGoalEdit
    var isUpdate: Bool { edit.original != nil }

    /// An update that changes nothing is a description of the goal, not a
    /// proposal; showing it as "suggested changes" would confuse anyone.
    var isNoOp: Bool {
        guard let original = edit.original else { return false }
        let trimmed = { (text: String) in text.trimmingCharacters(in: .whitespacesAndNewlines) }
        return trimmed(edit.specificText) == trimmed(original.specificText)
            && edit.targetCount == original.targetCount
            && edit.relevantTheme == original.relevantTheme
            && Calendar.current.isDate(edit.endDate, inSameDayAs: original.endDate)
            && edit.plan == original.plan
    }

    static func make(
        operation: String,
        goalID: String?,
        specificText: String?,
        targetCount: Int?,
        theme: String?,
        daysFromToday: Int?,
        goals: [SMARTGoal],
        focusedGoalID: UUID? = nil,
        now: Date = Date(),
        personalReason: String? = nil,
        cue: String? = nil,
        expectedBarriers: String? = nil,
        fallbackAction: String? = nil
    ) -> CoachGoalProposal? {
        guard ["create", "update"].contains(operation) else { return nil }
        if let targetCount, !(1...30).contains(targetCount) { return nil }
        if let theme, SMARTRelevantTheme(rawValue: theme) == nil { return nil }
        if let specificText, specificText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || specificText.count > 500 { return nil }
        if let daysFromToday, !(1...30).contains(daysFromToday) { return nil }
        let existing: SMARTGoal?
        if operation == "update" {
            guard let goalID, let id = UUID(uuidString: goalID),
                  let goal = goals.first(where: { $0.id == id }) else { return nil }
            if let focusedGoalID, id != focusedGoalID { return nil }
            existing = goal
        } else {
            guard goalID == nil || goalID?.isEmpty == true, daysFromToday != nil,
                  specificText != nil, targetCount != nil, theme != nil else { return nil }
            existing = nil
        }
        let id = UUID()
        var edit = SMARTGoalEdit(goal: existing, id: id, now: now)
        if let specificText { edit.specificText = specificText }
        if let targetCount { edit.targetCount = targetCount }
        if let theme, let relevantTheme = SMARTRelevantTheme(rawValue: theme) { edit.relevantTheme = relevantTheme }
        if let daysFromToday {
            edit.endDate = SMARTGoalLogic.endDate(createdAt: now, days: daysFromToday)
        }
        if let personalReason { edit.plan.personalReason = personalReason }
        if let cue { edit.plan.cue = cue }
        if let expectedBarriers { edit.plan.expectedBarriers = expectedBarriers }
        if let fallbackAction { edit.plan.fallbackAction = fallbackAction }
        guard edit.validationMessage(latest: existing, now: now) == nil else { return nil }
        return CoachGoalProposal(id: id, edit: edit)
    }
}

enum CoachGoalPlanning {
    static func isGoalConversation(message: String, focusedGoalID: UUID?, hasProposal: Bool) -> Bool {
        if focusedGoalID != nil || hasProposal { return true }
        let text = message.lowercased()
        let cues = [
            "smart goal", "formulate a goal", "create a goal", "edit my goal", "change my goal",
            "revise my goal", "set a goal", "a goal around", "a goal for", "make a goal",
            "new goal", "start a goal", "track a goal", "goal to "
        ]
        return cues.contains { text.contains($0) }
    }

    /// Separate from today's Health record: goal coaching works without Health access.
    static func context(
        goals: [SMARTGoal],
        focusedGoalID: UUID? = nil,
        previousProposal: CoachGoalProposal? = nil,
        now: Date = Date(),
        activitiesByGoal: [UUID: [SMARTGoalActivity]] = [:]
    ) -> String {
        let ordered = goals.sorted { lhs, rhs in
            if (lhs.id == focusedGoalID) != (rhs.id == focusedGoalID) { return lhs.id == focusedGoalID }
            let a = lhs.status == .active && !lhs.isComplete && lhs.endDate > now
            let b = rhs.status == .active && !rhs.isComplete && rhs.endDate > now
            if a != b { return a }
            return a ? lhs.endDate < rhs.endDate : lhs.endDate > rhs.endDate
        }
        var lines = ["Today is \(DateHelpers.formatDisplayDate(DateHelpers.localDateKey(from: now))).", "Saved SMART goals:"]
        if goals.isEmpty { lines.append("No SMART goals saved.") }
        for goal in ordered {
            let marker = goal.id == focusedGoalID ? "SELECTED " : ""
            lines.append("\(marker)goalID=\(goal.id.uuidString); theme=\(goal.relevantTheme.label); target=\(goal.targetCount); end=\(goal.endDate.formatted(date: .abbreviated, time: .shortened)); status=\(goal.status.rawValue).")
            lines.append(CoachGoalSummarizer.line(for: goal, today: now))
            for planLine in goal.plan.promptLines() {
                lines.append("Plan: \(planLine)")
            }
            let history = SMARTGoalActivityLogic.coachHistoryLines(
                for: activitiesByGoal[goal.id] ?? [],
                targetCount: goal.targetCount,
                fallbackAction: goal.plan.fallbackAction,
                now: now
            )
            lines.append(contentsOf: history)
        }
        if let focusedGoalID, !goals.contains(where: { $0.id == focusedGoalID }) {
            lines.append("The selected goal is no longer saved.")
        }
        if let previousProposal {
            let edit = previousProposal.edit
            lines.append("UNSAVED DRAFT (not a commitment): \(edit.summary.limitedToCoachBudget(450))")
            lines.append("Draft goalID: \(edit.original?.id.uuidString ?? "new goal").")
        }
        return lines.joined(separator: "\n")
    }

    /// Exact content signature, independent of Swift's per-process hash seed.
    /// The signature stays in the local coach cache, never analytics or logs.
    static func cacheKey(goals: [SMARTGoal]) -> String {
        goals.sorted { $0.id.uuidString < $1.id.uuidString }.map {
            "\($0.id)|\($0.specificText)|\($0.targetCount)|\($0.filledMask)|\($0.endDate.timeIntervalSince1970)|\($0.status.rawValue)|\($0.relevantTheme.rawValue)|\($0.plan.followThroughEnabled)"
        }.joined(separator: ";")
    }

    static func starterQuestions(for goal: SMARTGoal?) -> [String] {
        _ = goal
        return []
    }
}
