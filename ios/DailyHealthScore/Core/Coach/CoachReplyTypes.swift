import Foundation

/// What the reply needs to know about the chat it is answering in. Small on
/// purpose: the conversation lives in the session, the facts live in the tools.
struct CoachReplyContext: Equatable, Sendable {
    var thread: CoachThread?
    /// No Coach reply exists yet in this chat (openers do not count).
    var isFirstReply: Bool
}

/// A logged check-in the Coach heard in chat, waiting for the person to confirm.
struct CoachGoalCheckInRequest: Identifiable, Equatable, Sendable {
    let id: UUID
    var goalId: UUID
    var goalTitle: String
    var occurredAt: Date
    var note: String

    init(id: UUID = UUID(), goalId: UUID, goalTitle: String, occurredAt: Date, note: String) {
        self.id = id
        self.goalId = goalId
        self.goalTitle = goalTitle
        self.occurredAt = occurredAt
        self.note = note
    }

    /// The person said they did it. A question, or a message with no completion
    /// language in it, logs nothing no matter what the model returned.
    static func claimsCompletion(_ message: String) -> Bool {
        let text = " " + message.lowercased()
            .replacingOccurrences(of: "’", with: "'")
            .components(separatedBy: CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "'")).inverted)
            .filter { !$0.isEmpty }
            .joined(separator: " ") + " "
        let cues = [
            " i did ", " did it ", " did my ", " did the ", " done ", " finished ", " completed ", " logged ",
            " got it done ", " got it in ", " made it ", " went for ", " went on ", " i walked ", " we walked ",
            " i ran ", " i ate ", " i cooked ", " i meditated ", " just did ", " knocked out ", " this morning i ",
            " yesterday i ", " today i ", " i managed ", " i've done ", " i have done ", " checked off ",
            " crushed ", " nailed ", " i took ", " took my ", " i played ", " i read ", " i practiced ",
            " i journaled ", " i stretched ", " i called ", " check in ", " check-in ", " mark it ", " count it ",
            " log it ", " log that ", " i hit ", " i kept "
        ]
        return cues.contains { text.contains($0) }
    }

    /// Validates a model claim against the live goals. Nil means nothing to confirm.
    static func make(
        goalID: String,
        when: String,
        note: String,
        goals: [SMARTGoal],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> CoachGoalCheckInRequest? {
        guard let id = UUID(uuidString: goalID.trimmingCharacters(in: .whitespacesAndNewlines)),
              let goal = goals.first(where: { $0.id == id }),
              goal.canLogCheckIn else { return nil }
        let occurred: Date
        if when.lowercased().contains("yesterday"),
           let yesterday = calendar.date(byAdding: .day, value: -1, to: now) {
            occurred = yesterday
        } else {
            occurred = now
        }
        return CoachGoalCheckInRequest(
            goalId: goal.id,
            goalTitle: goal.specificText.trimmingCharacters(in: .whitespacesAndNewlines),
            occurredAt: occurred,
            note: String(note.trimmingCharacters(in: .whitespacesAndNewlines).prefix(140))
        )
    }
}

struct CoachReplyResult: Equatable {
    var message: String
    var memoryUpdates: [CoachMemoryUpdate]
    var goalCheckIn: CoachGoalCheckInRequest?
    var goalProposal: CoachGoalProposal?
    var proposalRejected: Bool
    /// Which model wrote the message.
    var tier: CoachModelTier
    /// A label for the eval screen; nothing steers on it.
    var shape: CoachReplyShape
    /// Why the server model did not answer, when the on-device retry did.
    var fallbackReason: String? = nil
    /// Tools the model called, in order.
    var toolsUsed: [String] = []
}

/// What the on-device filing pass returns for a chat.
struct CoachChatFiling: Equatable, Sendable {
    var title: String
    var summary: String
    var pillar: CoachPillar
}
