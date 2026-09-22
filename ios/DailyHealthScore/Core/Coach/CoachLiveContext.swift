import Foundation

/// Everything the Coach's tools can reach for during one reply, and the
/// actions the model asked the app to take. Facts are pulled on demand — the
/// model decides when a question needs them — and actions are validated here
/// before the app ever sees them. Only the app saves anything.
@MainActor
final class CoachLiveContext {
    // MARK: - Facts the tools read

    var snapshot: CoachSnapshot?
    /// Every stored day, for questions about a past day or stretch of days.
    var records: [DailyRecord] = []
    var todayKey: String = DateHelpers.localDateKey()
    var goals: [SMARTGoal] = []
    var activitiesByGoal: [UUID: [SMARTGoalActivity]] = [:]
    var memoryItems: [CoachMemoryItem] = []
    var recentConversations: String = ""
    var bodyTrend: BodyTrend?
    /// What the person has said in this exchange and recently; a new note has
    /// to come from here.
    var personsWords: String = ""
    /// The goal a chat was opened about, so an update never lands on another.
    var focusedGoalID: UUID?

    // MARK: - Actions the model asked for

    private(set) var pendingMemoryUpdates: [CoachMemoryUpdate] = []
    private(set) var pendingProposal: CoachGoalProposal?
    private(set) var pendingCheckIn: CoachGoalCheckInRequest?
    private(set) var proposalRejected = false
    /// Tool calls the model made, with only the arguments that affected the
    /// operation and a small outcome. Ephemeral: shown by the eval, never filed.
    private(set) var toolLog: [String] = []

    init() {}

    func beginTurn() {
        pendingMemoryUpdates = []
        pendingProposal = nil
        pendingCheckIn = nil
        proposalRejected = false
        toolLog = []
    }

    func log(
        _ tool: String,
        detail: String? = nil,
        outcome: String? = nil,
        startedAt: Date? = nil
    ) {
        var line = tool
        if let detail {
            let clean = detail
                .replacingOccurrences(of: "\n", with: " ")
                .replacingOccurrences(of: "\"", with: "'")
                .split(whereSeparator: \.isWhitespace)
                .joined(separator: " ")
            if !clean.isEmpty {
                line += "(\"\(String(clean.prefix(100)))\")"
            }
        }
        if let outcome, !outcome.isEmpty {
            line += " → \(outcome)"
        }
        if let startedAt {
            let milliseconds = max(Int(Date().timeIntervalSince(startedAt) * 1_000), 0)
            line += " · \(milliseconds) ms"
        }
        toolLog.append(line)
    }

    // MARK: - Payloads

    var todayPayload: String {
        snapshot?.promptBlock ?? "No live daily record is available right now. Say so; never invent numbers."
    }

    /// Any past day or window. Unreadable arguments get the dates back rather
    /// than an empty answer, so the next call can land.
    func daysPayload(startDate: String?, endDate: String?, startDaysAgo: Int?, endDaysAgo: Int?) -> String {
        guard let window = CoachDayRange.resolve(
            startDate: startDate,
            endDate: endDate,
            startDaysAgo: startDaysAgo,
            endDaysAgo: endDaysAgo,
            todayKey: todayKey
        ) else {
            return CoachDayRange.guidance(todayKey: todayKey)
        }
        return CoachDayRange.payload(records: records, window: window, todayKey: todayKey)
    }

    var goalsPayload: String {
        let text = CoachGoalPlanning.context(
            goals: goals,
            focusedGoalID: focusedGoalID,
            previousProposal: nil,
            activitiesByGoal: activitiesByGoal
        )
        return text.isEmpty ? "No SMART goals saved." : text
    }

    func personPayload(topic: String) -> String {
        let notes = CoachMemoryLogic.promptBlock(items: memoryItems, relevantTo: topic)
        let conversations = relevantConversationLines(topic: topic)
        var parts: [String] = []
        parts.append("SAVED NOTES:\n" + notes)
        if !conversations.isEmpty {
            parts.append("RECENT CONVERSATIONS (other chats):\n" + conversations)
        }
        return parts.joined(separator: "\n\n")
    }

    var bodyPayload: String {
        bodyTrend?.promptBlock ?? "No weight, height, age, or sex has been shared from Apple Health."
    }

    private func relevantConversationLines(topic: String) -> String {
        let words = CoachMemoryLogic.substanceWords(in: topic)
        guard !words.isEmpty else { return "" }
        let normalized = topic.lowercased()
        let broad = ["everything", "whole profile", "full profile", "all notes", "background"]
            .contains { normalized.contains($0) }
        let lines = recentConversations
            .split(separator: "\n")
            .map(String.init)
        let relevant = broad ? lines : lines.filter {
            !CoachMemoryLogic.substanceWords(in: $0).intersection(words).isEmpty
        }
        return relevant.prefix(4).joined(separator: "\n")
    }

    // MARK: - Actions

    /// A note is kept only when it is valid for the files and comes from the
    /// person's own words. Returns what the model should be told.
    func remember(operation: String, section: String, text: String, replaces: String, basis: String) -> String {
        guard let update = CoachMemoryUpdate(operation: operation, section: section, text: text, replaces: replaces, basis: basis) else {
            return "Not kept: the note needs a valid file (aboutYou, people, patterns, coaching, goals, likes, routines, body, recent), an operation (add, update, remove), and text under 240 characters."
        }
        guard CoachMemoryLogic.isGrounded(update, inPersonsWords: personsWords) else {
            return "Not kept: notes must come from what the person actually said, not from your own suggestions."
        }
        pendingMemoryUpdates.append(update)
        return "Kept."
    }

    func propose(
        operation: String,
        goalID: String?,
        specificText: String?,
        targetCount: Int?,
        theme: String?,
        daysFromToday: Int?,
        personalReason: String?,
        cue: String?,
        expectedBarriers: String?,
        fallbackAction: String?
    ) -> String {
        let proposal = CoachGoalProposal.make(
            operation: operation,
            goalID: goalID,
            specificText: specificText,
            targetCount: targetCount,
            theme: theme,
            daysFromToday: daysFromToday,
            goals: goals,
            focusedGoalID: focusedGoalID,
            personalReason: personalReason,
            cue: cue,
            expectedBarriers: expectedBarriers,
            fallbackAction: fallbackAction
        )
        guard let proposal else {
            let kept = pendingProposal != nil
            if !kept { proposalRejected = true }
            let reason = "Not drafted: a new goal needs specificText, targetCount (1–30), theme (marriage, parenting, health, relationships, finances, career, choresMisc), and daysFromToday (1–30); an update needs an exact goalID from the saved goals."
            return kept ? reason + " The draft already on screen is unchanged." : reason
        }
        if proposal.isNoOp {
            return "Not drafted: that is the goal exactly as it already is."
        }
        let replaced = pendingProposal != nil
        pendingProposal = proposal
        proposalRejected = false
        if replaced {
            return "Replaced the earlier draft. Only this latest one is on screen. It is not saved yet."
        }
        return "One draft is on screen. It is not saved yet."
    }

    func logCheckIn(goalID: String, when: String, note: String) -> String {
        guard CoachGoalCheckInRequest.claimsCompletion(personsWords) else {
            return "Not offered: the person has not said they completed it."
        }
        guard let request = CoachGoalCheckInRequest.make(goalID: goalID, when: when, note: note, goals: goals) else {
            return "Not offered: use an exact goalID from the saved goals, and only for a goal that can still take a check-in."
        }
        pendingCheckIn = request
        return "Ready for them to confirm. It is not logged yet."
    }
}
