import Foundation

enum CoachSnapshotBuilder {
    static func build(
        today: DailyRecord,
        records: [DailyRecord],
        phase: DayPhase = .current()
    ) -> CoachSnapshot {
        let weekKeys = DateHelpers.rollingDateKeys(days: 7)
        let weekStats = RollingStatsCalculator.compute(records: records, windowKeys: weekKeys)
        let weekRecords = weekStats?.recordsInWindow ?? []
        let fiberDays = weekRecords.filter { $0.fiberGrams > 0 }.count

        return CoachSnapshot(
            todayKey: today.date,
            dayPhase: phase,
            totalScore: today.totalScore,
            sleepHours: today.sleepHours,
            sleepGoal: today.sleepGoal.rawValue,
            sleepScore: today.sleepScore,
            fiberGrams: today.fiberGrams,
            fiberGoal: Double(today.fiberGoal.rawValue),
            fiberScore: today.fiberScore,
            exerciseMinutes: today.exerciseMinutes,
            exerciseGoal: Double(today.exerciseGoalMinutes),
            exerciseScore: today.exerciseScore,
            primaryFocus: today.primaryFocus,
            weekDaysWithData: weekStats?.daysWithData ?? 0,
            weekAvgScore: weekStats?.avgTotalScore,
            weekAvgSleep: weekStats?.avgSleepHours,
            weekAvgFiber: weekStats?.avgFiberGrams,
            weekAvgExercise: weekStats?.avgExerciseMinutes,
            fiberDaysLoggedInWeek: fiberDays,
            sleepPresentToday: today.sleepHours > 0,
            fiberPresentToday: today.fiberGrams > 0,
            exercisePresentToday: today.exerciseMinutes > 0
        )
    }
}
