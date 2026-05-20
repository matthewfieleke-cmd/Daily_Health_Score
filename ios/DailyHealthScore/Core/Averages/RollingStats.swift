import Foundation

struct RollingStats {
    var daysInWindow: Int
    var daysWithData: Int
    var avgTotalScore: Double
    var avgSleepHours: Double
    var avgFiberGrams: Double
    var avgExerciseMinutes: Double
    var avgSleepScore: Double
    var avgFiberScore: Double
    var avgExerciseScore: Double
    var recordsInWindow: [DailyRecord]
}

enum RollingStatsCalculator {
    static func compute(records: [DailyRecord], windowKeys: [String]) -> RollingStats? {
        let keySet = Set(windowKeys)
        let inWindow = records.filter { keySet.contains($0.date) }.sorted { $0.date > $1.date }
        guard !inWindow.isEmpty else { return nil }

        let recalculated = inWindow.map { record -> ScoreComputation in
            ScoreCalculator.calculate(
                metrics: DailyMetrics(
                    sleepHours: record.sleepHours,
                    fiberGrams: record.fiberGrams,
                    exerciseMinutes: record.exerciseMinutes
                ),
                settings: UserSettings(sleepGoal: record.sleepGoal, fiberGoal: record.fiberGoal)
            )
        }

        func mean(_ values: [Double]) -> Double {
            guard !values.isEmpty else { return 0 }
            return values.reduce(0, +) / Double(values.count)
        }

        return RollingStats(
            daysInWindow: windowKeys.count,
            daysWithData: inWindow.count,
            avgTotalScore: mean(recalculated.map(\.totalScore)),
            avgSleepHours: mean(inWindow.map(\.sleepHours)),
            avgFiberGrams: mean(inWindow.map(\.fiberGrams)),
            avgExerciseMinutes: mean(inWindow.map(\.exerciseMinutes)),
            avgSleepScore: mean(recalculated.map(\.sleepScore)),
            avgFiberScore: mean(recalculated.map(\.fiberScore)),
            avgExerciseScore: mean(recalculated.map(\.exerciseScore)),
            recordsInWindow: inWindow
        )
    }
}
