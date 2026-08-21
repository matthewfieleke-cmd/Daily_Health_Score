import Foundation

/// Why today was rebuilt. Complication transfers are scarce (~50/day), so
/// streaming Exercise Minutes must not spend them the way a finished workout does.
enum HealthChangeKind: Equatable, Sendable {
    /// Launch, returning to the app, pull-to-refresh, or Watch reachability.
    case foreground
    case sleep
    case fiber
    /// Minute-by-minute Exercise Minutes. Face updates only if a workout also ended.
    case exerciseMinutes
    /// An `HKWorkout` was saved (user ended a walk, hike, etc.).
    case workout
}

/// Decides when to call `transferCurrentComplicationUserInfo`.
enum ComplicationPushPolicy {
    /// Leave a few transfers for evening fiber / a late workout.
    static let reserveTransfers = 4

    struct Face: Equatable, Codable {
        var dateKey: String
        var formattedScore: String
        var sleep: Double
        var fiber: Double
        var exercise: Double
        var compactSleep: String
        var compactFiber: String
        var compactExercise: String
        var goals: [WatchGoalSnapshot]

        init(_ snapshot: WatchSnapshot) {
            dateKey = snapshot.dateKey
            formattedScore = snapshot.formattedScore
            sleep = snapshot.sleep.value
            fiber = snapshot.fiber.value
            exercise = snapshot.exercise.value
            compactSleep = snapshot.sleep.compactFaceValue
            compactFiber = snapshot.fiber.compactFaceValue
            compactExercise = snapshot.exercise.compactFaceValue
            goals = snapshot.goals
        }
    }

    static func shouldPushComplication(
        from previous: Face?,
        to next: Face,
        kind: HealthChangeKind,
        endedWorkoutSinceLastPush: Bool,
        remainingTransfers: Int
    ) -> Bool {
        guard remainingTransfers > 0 else { return false }

        if previous == nil { return true }
        if previous?.dateKey != next.dateKey { return true }

        let sleepChanged = previous?.sleep != next.sleep || previous?.compactSleep != next.compactSleep
        let fiberChanged = previous?.fiber != next.fiber || previous?.compactFiber != next.compactFiber
        let exerciseChanged = previous?.exercise != next.exercise
            || previous?.compactExercise != next.compactExercise
        let scoreChanged = previous?.formattedScore != next.formattedScore
        let goalsChanged = previous?.goals != next.goals
        let inReserve = remainingTransfers <= reserveTransfers

        switch kind {
        case .foreground:
            if inReserve {
                // Keep the last few transfers for dinner fiber / a late workout,
                // not for an app-open that only moved exercise minutes or goals.
                return sleepChanged || fiberChanged || scoreChanged
            }
            return sleepChanged || fiberChanged || exerciseChanged || scoreChanged || goalsChanged
        case .sleep:
            return sleepChanged || scoreChanged
        case .fiber:
            return fiberChanged || scoreChanged
        case .workout:
            return exerciseChanged || scoreChanged
        case .exerciseMinutes:
            guard endedWorkoutSinceLastPush else { return false }
            return exerciseChanged || scoreChanged
        }
    }
}

/// Remembers the last face that actually received a complication transfer so a
/// HealthKit process launch does not look like "first snapshot" and burn the
/// daily budget.
enum LastComplicationFaceStore {
    static let defaultsKey = "dhs.lastComplicationFaceJSON"

    static func load(defaults: UserDefaults = .standard) -> ComplicationPushPolicy.Face? {
        guard let json = defaults.string(forKey: defaultsKey) else { return nil }
        return WatchBridge.decode(ComplicationPushPolicy.Face.self, from: json)
    }

    static func save(_ face: ComplicationPushPolicy.Face?, defaults: UserDefaults = .standard) {
        if let face, let json = WatchBridge.encode(face) {
            defaults.set(json, forKey: defaultsKey)
        } else {
            defaults.removeObject(forKey: defaultsKey)
        }
    }
}

/// A snapshot that could not be sent because Watch Connectivity was still
/// activating. Always keep the newest snapshot; remember a workout if either
/// attempt had one.
struct WatchPendingSend: Equatable {
    var snapshot: WatchSnapshot
    var kind: HealthChangeKind
    var endedWorkoutSinceLastPush: Bool
    var latestWorkoutEnd: Date?
}

enum WatchPendingSendMerge {
    static func replacing(
        _ current: WatchPendingSend?,
        with incoming: WatchPendingSend
    ) -> WatchPendingSend {
        guard let current else { return incoming }
        var merged = incoming
        merged.kind = preferredKind(current.kind, incoming.kind)
        merged.endedWorkoutSinceLastPush =
            current.endedWorkoutSinceLastPush || incoming.endedWorkoutSinceLastPush
        switch (current.latestWorkoutEnd, incoming.latestWorkoutEnd) {
        case let (older?, newer?):
            merged.latestWorkoutEnd = max(older, newer)
        case let (older?, nil):
            merged.latestWorkoutEnd = older
        default:
            break
        }
        return merged
    }

    /// Foreground is the most generous complication rule. A workout flag must
    /// not be forgotten if a later sleep publish replaces the queued payload.
    static func preferredKind(_ older: HealthChangeKind, _ newer: HealthChangeKind) -> HealthChangeKind {
        if older == .foreground || newer == .foreground { return .foreground }
        if older == .workout || newer == .workout { return .workout }
        if older == .sleep || newer == .sleep { return .sleep }
        if older == .fiber || newer == .fiber { return .fiber }
        return newer
    }
}
