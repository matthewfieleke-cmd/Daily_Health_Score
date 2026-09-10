import Foundation
import SwiftData

@Model
final class SMARTGoalActivityEntity {
    @Attribute(.unique) var id: UUID
    var goalId: UUID
    var kindRaw: String
    var sourceRaw: String
    var occurredAt: Date?
    var recordedAt: Date
    var timeZoneIdentifier: String
    var localDateKey: String
    var reflectionText: String
    var revisionJSON: String
    var relatedEventId: UUID?
    var clientEventId: String
    var countsTowardTarget: Bool
    var note: String

    init(activity: SMARTGoalActivity) {
        id = activity.id
        goalId = activity.goalId
        kindRaw = activity.kind.rawValue
        sourceRaw = activity.source.rawValue
        occurredAt = activity.occurredAt
        recordedAt = activity.recordedAt
        timeZoneIdentifier = activity.timeZoneIdentifier
        localDateKey = activity.localDateKey
        reflectionText = activity.reflectionText
        revisionJSON = Self.encodeRevision(activity.revision)
        relatedEventId = activity.relatedEventId
        clientEventId = activity.clientEventId
        countsTowardTarget = activity.countsTowardTarget
        note = activity.note
    }

    func apply(_ activity: SMARTGoalActivity) {
        goalId = activity.goalId
        kindRaw = activity.kind.rawValue
        sourceRaw = activity.source.rawValue
        occurredAt = activity.occurredAt
        recordedAt = activity.recordedAt
        timeZoneIdentifier = activity.timeZoneIdentifier
        localDateKey = activity.localDateKey
        reflectionText = activity.reflectionText
        revisionJSON = Self.encodeRevision(activity.revision)
        relatedEventId = activity.relatedEventId
        clientEventId = activity.clientEventId
        countsTowardTarget = activity.countsTowardTarget
        note = activity.note
    }

    func toActivity() -> SMARTGoalActivity? {
        guard let kind = SMARTGoalActivityKind(rawValue: kindRaw),
              let source = SMARTGoalActivitySource(rawValue: sourceRaw) else {
            return nil
        }
        return SMARTGoalActivity(
            id: id,
            goalId: goalId,
            kind: kind,
            source: source,
            occurredAt: occurredAt,
            recordedAt: recordedAt,
            timeZoneIdentifier: timeZoneIdentifier,
            localDateKey: localDateKey,
            reflectionText: reflectionText,
            revision: Self.decodeRevision(revisionJSON),
            relatedEventId: relatedEventId,
            clientEventId: clientEventId,
            countsTowardTarget: countsTowardTarget,
            note: note
        )
    }

    private static func encodeRevision(_ revision: SMARTGoalRevisionSnapshot?) -> String {
        guard let revision,
              let data = try? JSONEncoder().encode(revision),
              let json = String(data: data, encoding: .utf8) else {
            return ""
        }
        return json
    }

    private static func decodeRevision(_ json: String) -> SMARTGoalRevisionSnapshot? {
        guard let data = json.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(SMARTGoalRevisionSnapshot.self, from: data)
    }
}
