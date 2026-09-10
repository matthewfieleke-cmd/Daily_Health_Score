import Foundation
import SwiftData

@Model
final class CoachChatMessageEntity {
    var id: UUID
    var roleRaw: String
    var text: String
    var createdAt: Date

    init(turn: CoachChatTurn) {
        id = turn.id
        roleRaw = turn.role.rawValue
        text = turn.text
        createdAt = turn.createdAt
    }

    func toTurn() -> CoachChatTurn? {
        guard let role = CoachChatTurn.Role(rawValue: roleRaw) else { return nil }
        return CoachChatTurn(id: id, role: role, text: text, createdAt: createdAt)
    }
}

@Model
final class CoachMemoryStateEntity {
    var id: String
    var runningSummary: String
    var profileJSON: String
    var dailyCardDateKey: String
    var dailyCardJSON: String
    var updatedAt: Date
    var memoryRevision: Int = 0
    var deletedFingerprintsJSON: String = "[]"

    init(
        id: String = "default",
        runningSummary: String = "",
        profileJSON: String = "",
        dailyCardDateKey: String = "",
        dailyCardJSON: String = "",
        updatedAt: Date = Date(),
        memoryRevision: Int = 0,
        deletedFingerprintsJSON: String = "[]"
    ) {
        self.id = id
        self.runningSummary = runningSummary
        self.profileJSON = profileJSON
        self.dailyCardDateKey = dailyCardDateKey
        self.dailyCardJSON = dailyCardJSON
        self.updatedAt = updatedAt
        self.memoryRevision = memoryRevision
        self.deletedFingerprintsJSON = deletedFingerprintsJSON
    }
}

@Model
final class CoachMemoryItemEntity {
    @Attribute(.unique) var id: UUID
    var categoryRaw: String
    var content: String
    var provenanceRaw: String
    var createdAt: Date
    var lastConfirmedAt: Date?
    var expiresAt: Date?
    var associatedGoalId: UUID?
    var confirmationRaw: String
    var isDeleted: Bool
    var contentFingerprint: String
    var supersededById: UUID?
    var sourceTurnId: UUID?
    var isTemporary: Bool

    init(item: CoachMemoryItem) {
        id = item.id
        categoryRaw = item.category.rawValue
        content = item.content
        provenanceRaw = item.provenance.rawValue
        createdAt = item.createdAt
        lastConfirmedAt = item.lastConfirmedAt
        expiresAt = item.expiresAt
        associatedGoalId = item.associatedGoalId
        confirmationRaw = item.confirmation.rawValue
        isDeleted = item.isDeleted
        contentFingerprint = item.contentFingerprint
        supersededById = item.supersededById
        sourceTurnId = item.sourceTurnId
        isTemporary = item.isTemporary
    }

    func apply(_ item: CoachMemoryItem) {
        categoryRaw = item.category.rawValue
        content = item.content
        provenanceRaw = item.provenance.rawValue
        createdAt = item.createdAt
        lastConfirmedAt = item.lastConfirmedAt
        expiresAt = item.expiresAt
        associatedGoalId = item.associatedGoalId
        confirmationRaw = item.confirmation.rawValue
        isDeleted = item.isDeleted
        contentFingerprint = item.contentFingerprint
        supersededById = item.supersededById
        sourceTurnId = item.sourceTurnId
        isTemporary = item.isTemporary
    }

    func toItem() -> CoachMemoryItem? {
        guard let category = CoachMemoryCategory(rawValue: categoryRaw),
              let provenance = CoachMemoryProvenance(rawValue: provenanceRaw),
              let confirmation = CoachMemoryConfirmation(rawValue: confirmationRaw) else {
            return nil
        }
        return CoachMemoryItem(
            id: id,
            category: category,
            content: content,
            provenance: provenance,
            createdAt: createdAt,
            lastConfirmedAt: lastConfirmedAt,
            expiresAt: expiresAt,
            associatedGoalId: associatedGoalId,
            confirmation: confirmation,
            isDeleted: isDeleted,
            contentFingerprint: contentFingerprint,
            supersededById: supersededById,
            sourceTurnId: sourceTurnId,
            isTemporary: isTemporary
        )
    }
}

@Model
final class CoachFollowThroughStateEntity {
    @Attribute(.unique) var goalId: UUID
    var lastReminderAt: Date?
    var lastReflectionAt: Date?
    var lastReviewAt: Date?
    var snoozeUntil: Date?
    var dismissedDateKey: String

    init(goalId: UUID) {
        self.goalId = goalId
        lastReminderAt = nil
        lastReflectionAt = nil
        lastReviewAt = nil
        snoozeUntil = nil
        dismissedDateKey = ""
    }
}

struct CoachFollowThroughState: Equatable {
    var goalId: UUID
    var lastReminderAt: Date?
    var lastReflectionAt: Date?
    var lastReviewAt: Date?
    var snoozeUntil: Date?
    var dismissedDateKey: String

    init(entity: CoachFollowThroughStateEntity) {
        goalId = entity.goalId
        lastReminderAt = entity.lastReminderAt
        lastReflectionAt = entity.lastReflectionAt
        lastReviewAt = entity.lastReviewAt
        snoozeUntil = entity.snoozeUntil
        dismissedDateKey = entity.dismissedDateKey
    }

    init(
        goalId: UUID,
        lastReminderAt: Date? = nil,
        lastReflectionAt: Date? = nil,
        lastReviewAt: Date? = nil,
        snoozeUntil: Date? = nil,
        dismissedDateKey: String = ""
    ) {
        self.goalId = goalId
        self.lastReminderAt = lastReminderAt
        self.lastReflectionAt = lastReflectionAt
        self.lastReviewAt = lastReviewAt
        self.snoozeUntil = snoozeUntil
        self.dismissedDateKey = dismissedDateKey
    }
}

@Model
final class CoachLocalFeedbackEntity {
    @Attribute(.unique) var id: UUID
    var targetRaw: String
    var useful: Bool
    var createdAt: Date
    var goalId: UUID?

    init(id: UUID = UUID(), target: String, useful: Bool, createdAt: Date = Date(), goalId: UUID? = nil) {
        self.id = id
        self.targetRaw = target
        self.useful = useful
        self.createdAt = createdAt
        self.goalId = goalId
    }
}
