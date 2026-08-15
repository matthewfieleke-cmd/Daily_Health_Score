import Foundation

enum WatchSnapshotBuilder {
    static let maxGoals = 8

    static func build(
        today: DailyRecord?,
        goals: [SMARTGoal],
        paceNudgesEnabled: Bool,
        now: Date = Date()
    ) -> WatchSnapshot {
        let record = today
        let sleepGoal = record?.sleepGoal.rawValue ?? SleepGoalHours.sevenHalf.rawValue
        let fiberGoal = Double(record?.fiberGoal.rawValue ?? FiberGoalGrams.forty.rawValue)
        let exerciseGoal = Double(record?.exerciseGoalMinutes ?? Int(ScoreCalculator.exerciseGoalMinutes))

        return WatchSnapshot(
            dateKey: record?.date ?? DateHelpers.localDateKey(from: now),
            totalScore: record?.totalScore ?? 0,
            sleep: WatchPillarSnapshot(
                name: "Sleep",
                value: record?.sleepHours ?? 0,
                goal: sleepGoal,
                unit: "hr",
                points: record?.sleepScore ?? 0,
                maxPoints: 4
            ),
            fiber: WatchPillarSnapshot(
                name: "Fiber",
                value: record?.fiberGrams ?? 0,
                goal: fiberGoal,
                unit: "g",
                points: record?.fiberScore ?? 0,
                maxPoints: 4
            ),
            exercise: WatchPillarSnapshot(
                name: "Exercise",
                value: record?.exerciseMinutes ?? 0,
                goal: exerciseGoal,
                unit: "min",
                points: record?.exerciseScore ?? 0,
                maxPoints: 2
            ),
            goals: compactGoals(goals),
            updatedAt: now,
            paceNudgesEnabled: paceNudgesEnabled
        )
    }

    private static func compactGoals(_ goals: [SMARTGoal]) -> [WatchGoalSnapshot] {
        let ordered = goals
            .filter { $0.status == .active }
            .sorted { lhs, rhs in
                if lhs.isComplete != rhs.isComplete { return !lhs.isComplete }
                return lhs.endDate < rhs.endDate
            }
        return ordered.prefix(maxGoals).map { goal in
            WatchGoalSnapshot(
                id: goal.id,
                specificText: goal.specificText,
                targetCount: goal.targetCount,
                filledMask: goal.filledMask,
                statusRaw: goal.status.rawValue
            )
        }
    }
}
