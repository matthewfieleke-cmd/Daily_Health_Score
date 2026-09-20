import Foundation

/// Everything the reply pipeline needs to know about the chat it is answering in.
struct CoachReplyContext: Equatable, Sendable {
    var thread: CoachThread?
    /// No Coach reply exists yet in this chat (openers do not count).
    var isFirstReply: Bool
    var pillar: CoachPillar
    var allowUnpromptedHealth: Bool
    var recentConversations: String
    var goalPaceDirective: String?
    var isAcquaintance: Bool { thread?.kind == .acquaintance }
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
    var shape: CoachReplyShape
}

/// What the on-device filing pass returns for a chat.
struct CoachChatFiling: Equatable, Sendable {
    var title: String
    var summary: String
    var pillar: CoachPillar
}
