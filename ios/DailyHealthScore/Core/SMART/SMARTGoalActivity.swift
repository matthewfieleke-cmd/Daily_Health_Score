import Foundation

enum SMARTGoalActivityKind: String, Codable, Sendable {
    case checkIn
    case undo
    case correction
    case reflection
    case revision
    case fallbackCheckIn
}

enum SMARTGoalActivitySource: String, Codable, Sendable {
    case iPhone
    case watch
    case userEntry
    case migration
    case notification
}

struct SMARTGoalRevisionSnapshot: Equatable, Codable, Sendable {
    var specificText: String
    var targetCount: Int
    var relevantThemeRaw: String
    var endDate: Date
    var timeWindowDays: Int
    var personalReason: String
    var cue: String
    var expectedBarriers: String
    var fallbackAction: String
    var confidence: Int?

    static func from(_ goal: SMARTGoal) -> SMARTGoalRevisionSnapshot {
        SMARTGoalRevisionSnapshot(
            specificText: goal.specificText,
            targetCount: goal.targetCount,
            relevantThemeRaw: goal.relevantTheme.rawValue,
            endDate: goal.endDate,
            timeWindowDays: goal.timeWindowDays,
            personalReason: goal.plan.personalReason,
            cue: goal.plan.cue,
            expectedBarriers: goal.plan.expectedBarriers,
            fallbackAction: goal.plan.fallbackAction,
            confidence: goal.plan.confidence
        )
    }

    var describesPlanChange: Bool { true }
}

struct SMARTGoalActivity: Identifiable, Equatable, Codable, Sendable {
    var id: UUID
    var goalId: UUID
    var kind: SMARTGoalActivityKind
    var source: SMARTGoalActivitySource
    /// When the action happened. Nil for migrated check-ins whose dates were never known.
    var occurredAt: Date?
    var recordedAt: Date
    var timeZoneIdentifier: String
    var localDateKey: String
    var reflectionText: String
    var revision: SMARTGoalRevisionSnapshot?
    var relatedEventId: UUID?
    var clientEventId: String
    var countsTowardTarget: Bool
    var note: String

    init(
        id: UUID = UUID(),
        goalId: UUID,
        kind: SMARTGoalActivityKind,
        source: SMARTGoalActivitySource,
        occurredAt: Date?,
        recordedAt: Date = Date(),
        timeZoneIdentifier: String = TimeZone.current.identifier,
        localDateKey: String = "",
        reflectionText: String = "",
        revision: SMARTGoalRevisionSnapshot? = nil,
        relatedEventId: UUID? = nil,
        clientEventId: String = "",
        countsTowardTarget: Bool = false,
        note: String = ""
    ) {
        self.id = id
        self.goalId = goalId
        self.kind = kind
        self.source = source
        self.occurredAt = occurredAt
        self.recordedAt = recordedAt
        self.timeZoneIdentifier = timeZoneIdentifier
        self.localDateKey = localDateKey
        self.reflectionText = reflectionText
        self.revision = revision
        self.relatedEventId = relatedEventId
        self.clientEventId = clientEventId
        self.countsTowardTarget = countsTowardTarget
        self.note = note
    }

    var hasKnownOccurrenceDate: Bool { occurredAt != nil }

    var sourceLabel: String {
        switch source {
        case .iPhone: return "iPhone"
        case .watch: return "Watch"
        case .userEntry: return "You"
        case .migration: return "Earlier progress (date unknown)"
        case .notification: return "Reminder"
        }
    }
}

enum SMARTGoalProgress {
    static func mask(filledCount: Int, targetCount: Int) -> Int {
        let n = min(max(filledCount, 0), max(targetCount, 0))
        guard n > 0 else { return 0 }
        return (1 << n) - 1
    }

    static func filledCount(mask: Int, targetCount: Int) -> Int {
        (0 ..< max(targetCount, 0)).filter { (mask & (1 << $0)) != 0 }.count
    }
}

/// Progress and coaching sentences are computed here so the model never
/// invents dates, streaks, or extra completed actions from a plan change.
enum SMARTGoalActivityLogic {
    static func undoneIDs(in events: [SMARTGoalActivity]) -> Set<UUID> {
        Set(events.filter { $0.kind == .undo }.compactMap(\.relatedEventId))
    }

    static func activeCheckIns(in events: [SMARTGoalActivity]) -> [SMARTGoalActivity] {
        let undone = undoneIDs(in: events)
        return events
            .filter { $0.kind == .checkIn && $0.countsTowardTarget && !undone.contains($0.id) }
            .sorted(by: checkInOrder)
    }

    static func activeFallbacks(in events: [SMARTGoalActivity]) -> [SMARTGoalActivity] {
        let undone = undoneIDs(in: events)
        return events
            .filter { $0.kind == .fallbackCheckIn && !undone.contains($0.id) }
            .sorted(by: checkInOrder)
    }

    static func netCheckInCount(in events: [SMARTGoalActivity]) -> Int {
        activeCheckIns(in: events).count
    }

    static func filledMask(from events: [SMARTGoalActivity], targetCount: Int) -> Int {
        SMARTGoalProgress.mask(
            filledCount: netCheckInCount(in: events),
            targetCount: targetCount
        )
    }

    static func hasUndatedProgress(_ events: [SMARTGoalActivity]) -> Bool {
        activeCheckIns(in: events).contains { !$0.hasKnownOccurrenceDate }
    }

    /// Streaks require every contributing check-in to have a user-known date.
    /// Migrated undated history returns an empty list so callers cannot claim one.
    static func datedOccurrenceKeys(_ events: [SMARTGoalActivity]) -> [String] {
        guard !hasUndatedProgress(events) else { return [] }
        return activeCheckIns(in: events)
            .map(\.localDateKey)
            .filter { !$0.isEmpty }
    }

    static func alreadyProcessed(clientEventId: String, in events: [SMARTGoalActivity]) -> Bool {
        let trimmed = clientEventId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        return events.contains { $0.clientEventId == trimmed }
    }

    static func undatedCheckInsFromLegacyMask(
        mask: Int,
        targetCount: Int,
        goalId: UUID,
        recordedAt: Date
    ) -> [SMARTGoalActivity] {
        let count = SMARTGoalProgress.filledCount(mask: mask, targetCount: targetCount)
        guard count > 0 else { return [] }
        return (0 ..< count).map { index in
            SMARTGoalActivity(
                goalId: goalId,
                kind: .checkIn,
                source: .migration,
                occurredAt: nil,
                recordedAt: recordedAt,
                timeZoneIdentifier: TimeZone.current.identifier,
                localDateKey: "",
                clientEventId: "migration:\(goalId.uuidString):\(index)",
                countsTowardTarget: true,
                note: "Migrated from earlier check-in count. No occurrence date is known."
            )
        }
    }

    static func planChanged(from previous: SMARTGoal, to current: SMARTGoal) -> Bool {
        SMARTGoalRevisionSnapshot.from(previous) != SMARTGoalRevisionSnapshot.from(current)
    }

    static func coachHistoryLines(
        for events: [SMARTGoalActivity],
        targetCount: Int,
        fallbackAction: String,
        now: Date = Date()
    ) -> [String] {
        let checkIns = activeCheckIns(in: events)
        let fallbacks = activeFallbacks(in: events)
        let revisions = events.filter { $0.kind == .revision }.sorted { $0.recordedAt < $1.recordedAt }
        var lines: [String] = []
        lines.append(
            "Recorded progress: \(checkIns.count) of \(targetCount) accepted check-ins."
        )
        if hasUndatedProgress(events) {
            lines.append(
                "Some check-ins have no action date (migrated from earlier counts). Do not claim a streak, a missed day, or a schedule from them."
            )
        } else if checkIns.isEmpty {
            lines.append(
                "No accepted check-ins are recorded. A missing check-in does not prove the action was missed."
            )
        } else {
            let dated = checkIns.filter(\.hasKnownOccurrenceDate)
            if !dated.isEmpty {
                let keys = dated.map(\.localDateKey).filter { !$0.isEmpty }
                lines.append("Dated check-ins on: \(keys.joined(separator: ", ")).")
            }
        }
        if !fallbacks.isEmpty {
            let name = fallbackAction.trimmingCharacters(in: .whitespacesAndNewlines)
            let label = name.isEmpty ? "a smaller step" : name
            lines.append(
                "\(fallbacks.count) smaller fallback action(s) recorded (\(label)). These do not satisfy the accepted goal."
            )
        }
        for revision in revisions.suffix(3) {
            if let snapshot = revision.revision {
                lines.append(
                    "Plan revision on \(revision.recordedAt.formatted(date: .abbreviated, time: .omitted)): previous target \(snapshot.targetCount), action \"\(snapshot.specificText.limitedToCoachBudget(60))\". A reduced target is a plan change, not another completed action."
                )
            }
        }
        let reflections = events.filter { $0.kind == .reflection && !$0.reflectionText.isEmpty }
        for reflection in reflections.suffix(3) {
            lines.append("Reflection: \(reflection.reflectionText.limitedToCoachBudget(140))")
        }
        _ = now
        return lines
    }

    private static func checkInOrder(_ lhs: SMARTGoalActivity, _ rhs: SMARTGoalActivity) -> Bool {
        switch (lhs.occurredAt, rhs.occurredAt) {
        case let (left?, right?):
            if left != right { return left < right }
        case (nil, .some):
            return true
        case (.some, nil):
            return false
        default:
            break
        }
        return lhs.recordedAt < rhs.recordedAt
    }
}
