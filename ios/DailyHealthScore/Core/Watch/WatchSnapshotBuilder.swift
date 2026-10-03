import Foundation

enum WatchSnapshotBuilder {
    static let maxGoals = 8

    static func build(
        today: DailyRecord?,
        goals: [SMARTGoal],
        paceNudgesEnabled: Bool,
        nutritionMode: NutritionMode = .fiber,
        now: Date = Date()
    ) -> WatchSnapshot {
        let record = today
        let sleepGoal = record?.sleepGoal.rawValue ?? SleepGoalHours.sevenHalf.rawValue
        let movement = record?.movementGoal ?? .exerciseMinutes
        let fiber: WatchPillarSnapshot
        if nutritionMode == .foodGroups {
            fiber = WatchPillarSnapshot(
                name: "Food groups",
                value: record?.fiberScore ?? 0,
                goal: 4,
                unit: "pts",
                points: record?.fiberScore ?? 0,
                maxPoints: 4
            )
        } else {
            fiber = WatchPillarSnapshot(
                name: "Fiber",
                value: record?.fiberGrams ?? 0,
                goal: UserSettings.fiberGoalGrams,
                unit: "g",
                points: record?.fiberScore ?? 0,
                maxPoints: 4
            )
        }

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
            fiber: fiber,
            exercise: WatchPillarSnapshot(
                name: movement.metricName,
                value: record?.movementValue ?? 0,
                goal: movement.goalValue,
                unit: movement.unit,
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
