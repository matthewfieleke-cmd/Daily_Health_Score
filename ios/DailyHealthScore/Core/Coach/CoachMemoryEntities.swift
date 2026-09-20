import Foundation
import SwiftData

@Model
final class CoachChatMessageEntity {
    var id: UUID
    var roleRaw: String
    var text: String
    var createdAt: Date
    var threadId: UUID?
    /// Which model wrote a Coach turn; empty for user turns and older rows.
    var modelTierRaw: String = ""

    init(turn: CoachChatTurn) {
        id = turn.id
        roleRaw = turn.role.rawValue
        text = turn.text
        createdAt = turn.createdAt
        threadId = turn.threadId
        modelTierRaw = turn.modelTier?.rawValue ?? ""
    }

    func toTurn() -> CoachChatTurn? {
        guard let role = CoachChatTurn.Role(rawValue: roleRaw) else { return nil }
        return CoachChatTurn(
            id: id,
            role: role,
            text: text,
            createdAt: createdAt,
            threadId: threadId,
            modelTier: CoachModelTier(rawValue: modelTierRaw)
        )
    }
}

/// `roomRaw` keeps its build-19 storage name so existing rows stay readable;
/// it holds the pillar. New columns carry defaults for lightweight migration.
@Model
final class CoachThreadEntity {
    @Attribute(.unique) var id: UUID
    var roomRaw: String
    var title: String
    var createdAt: Date
    var updatedAt: Date
    var lastMessageAt: Date
    var healthMentionWindowKey: String
    var summary: String
    var kindRaw: String = "conversation"
    var titleIsProvisional: Bool = true
    var preview: String = ""
    var messageCount: Int = 0
    var contextNote: String = ""
    var goalId: UUID?

    init(thread: CoachThread) {
        id = thread.id
        roomRaw = thread.pillar.rawValue
        title = thread.title
        createdAt = thread.createdAt
        updatedAt = thread.updatedAt
        lastMessageAt = thread.lastMessageAt
        healthMentionWindowKey = thread.healthMentionWindowKey
        summary = thread.summary
        kindRaw = thread.kind.rawValue
        titleIsProvisional = thread.titleIsProvisional
        preview = thread.preview
        messageCount = thread.messageCount
        contextNote = thread.contextNote
        goalId = thread.goalId
    }

    func apply(_ thread: CoachThread) {
        roomRaw = thread.pillar.rawValue
        title = thread.title
        createdAt = thread.createdAt
        updatedAt = thread.updatedAt
        lastMessageAt = thread.lastMessageAt
        healthMentionWindowKey = thread.healthMentionWindowKey
        summary = thread.summary
        kindRaw = thread.kind.rawValue
        titleIsProvisional = thread.titleIsProvisional
        preview = thread.preview
        messageCount = thread.messageCount
        contextNote = thread.contextNote
        goalId = thread.goalId
    }

    func toThread() -> CoachThread {
        CoachThread(
            id: id,
            pillar: CoachPillar(storageValue: roomRaw),
            kind: CoachThreadKind(rawValue: kindRaw) ?? .conversation,
            title: title,
            titleIsProvisional: titleIsProvisional,
            preview: preview,
            messageCount: messageCount,
            createdAt: createdAt,
            updatedAt: updatedAt,
            lastMessageAt: lastMessageAt,
            healthMentionWindowKey: healthMentionWindowKey,
            summary: summary,
            contextNote: contextNote,
            goalId: goalId
        )
    }
}

/// One Coach edit to the memory files, kept so the person can undo it.
@Model
final class CoachMemoryChangeEntity {
    @Attribute(.unique) var id: UUID
    var kindRaw: String
    var sectionRaw: String
    var itemId: UUID
    var previousItemId: UUID?
    var previousContent: String
    var newContent: String
    var createdAt: Date
    var threadId: UUID?
    var isUndone: Bool

    init(change: CoachMemoryChange) {
        id = change.id
        kindRaw = change.kind.rawValue
        sectionRaw = change.section.rawValue
        itemId = change.itemId
        previousItemId = change.previousItemId
        previousContent = change.previousContent
        newContent = change.newContent
        createdAt = change.createdAt
        threadId = change.threadId
        isUndone = change.isUndone
    }

    func apply(_ change: CoachMemoryChange) {
        kindRaw = change.kind.rawValue
        sectionRaw = change.section.rawValue
        itemId = change.itemId
        previousItemId = change.previousItemId
        previousContent = change.previousContent
        newContent = change.newContent
        createdAt = change.createdAt
        threadId = change.threadId
        isUndone = change.isUndone
    }

    func toChange() -> CoachMemoryChange? {
        guard let kind = CoachMemoryChangeKind(rawValue: kindRaw),
              let section = CoachMemorySection(rawValue: sectionRaw) else { return nil }
        return CoachMemoryChange(
            id: id,
            kind: kind,
            section: section,
            itemId: itemId,
            previousItemId: previousItemId,
            previousContent: previousContent,
            newContent: newContent,
            createdAt: createdAt,
            threadId: threadId,
            isUndone: isUndone
        )
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
    /// One paragraph per file, compiled on-device from the entries.
    var compiledProfile: String = ""
    /// Fingerprint of the entries the profile was compiled from.
    var compiledProfileKey: String = ""
    var lastFilesReviewAt: Date?

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
