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

    struct Face: Equatable {
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

        switch kind {
        case .foreground:
            return sleepChanged || fiberChanged || exerciseChanged || scoreChanged || goalsChanged
        case .sleep:
            return sleepChanged || scoreChanged
        case .fiber:
            return fiberChanged || scoreChanged
        case .workout:
            return exerciseChanged || scoreChanged
        case .exerciseMinutes:
            // Streaming minutes during a hike do not get a push. After the
            // workout object lands, one push is enough even if this observer
            // fired first.
            guard endedWorkoutSinceLastPush else { return false }
            return exerciseChanged || scoreChanged
        }
    }
}
