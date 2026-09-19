import Foundation
#if canImport(HealthKit)
import HealthKit
#endif

/// Last-resort face paint when the App Group is empty and Watch Connectivity
/// has not delivered a snapshot yet. Uses the same 4 + 4 + 2 math as iPhone.
enum WatchFaceScore {
    static let sleepGoalHours: Double = 7.5
    static let fiberGoalGrams: Double = 40
    static let exerciseGoalMinutes: Double = 30

    static func snapshot(
        dateKey: String,
        sleepHours: Double,
        fiberGrams: Double,
        exerciseMinutes: Double,
        now: Date = Date()
    ) -> WatchSnapshot {
        let sleepPoints = min(sleepHours / sleepGoalHours, 1) * 4
        let fiberPoints = min(fiberGrams / fiberGoalGrams, 1) * 4
        let exercisePoints = min(exerciseMinutes / exerciseGoalMinutes, 1) * 2
        return WatchSnapshot(
            dateKey: dateKey,
            totalScore: sleepPoints + fiberPoints + exercisePoints,
            sleep: WatchPillarSnapshot(
                name: "Sleep",
                value: sleepHours,
                goal: sleepGoalHours,
                unit: "hr",
                points: sleepPoints,
                maxPoints: 4
            ),
            fiber: WatchPillarSnapshot(
                name: "Fiber",
                value: fiberGrams,
                goal: fiberGoalGrams,
                unit: "g",
                points: fiberPoints,
                maxPoints: 4
            ),
            exercise: WatchPillarSnapshot(
                name: "Exercise",
                value: exerciseMinutes,
                goal: exerciseGoalMinutes,
                unit: "min",
                points: exercisePoints,
                maxPoints: 2
            ),
            goals: [],
            updatedAt: now,
            paceNudgesEnabled: true
        )
    }
}

enum WatchFaceHealthSnapshot {
    /// Builds today's snapshot from HealthKit. Returns nil when Health is
    /// unavailable, every query failed, or every pillar is still zero — so the
    /// face does not replace "Open iPhone" with a fake 0.0.
    static func loadToday(
        at now: Date = Date(),
        calendar: Calendar = .current
    ) async -> WatchSnapshot? {
        #if canImport(HealthKit)
        guard HKHealthStore.isHealthDataAvailable() else { return nil }
        let store = HKHealthStore()
        guard let dayStart = calendar.date(
            from: calendar.dateComponents([.year, .month, .day], from: now)
        ) else { return nil }
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? now

        async let sleep = sleepHours(store: store, dayStart: dayStart, dayEnd: dayEnd)
        async let fiber = sumQuantity(
            store: store,
            identifier: .dietaryFiber,
            unit: .gram(),
            start: dayStart,
            end: dayEnd
        )
        async let exercise = sumQuantity(
            store: store,
            identifier: .appleExerciseTime,
            unit: .minute(),
            start: dayStart,
            end: dayEnd
        )

        let sleepHours = await sleep
        let fiberGrams = await fiber
        let exerciseMinutes = await exercise
        if sleepHours == nil, fiberGrams == nil, exerciseMinutes == nil {
            return nil
        }
        let sleepValue = sleepHours ?? 0
        let fiberValue = fiberGrams ?? 0
        let exerciseValue = exerciseMinutes ?? 0
        guard sleepValue > 0 || fiberValue > 0 || exerciseValue > 0 else { return nil }

        let snapshot = WatchFaceScore.snapshot(
            dateKey: WatchBridge.localDateKey(from: now, calendar: calendar),
            sleepHours: sleepValue,
            fiberGrams: fiberValue,
            exerciseMinutes: exerciseValue,
            now: now
        )
        WatchSnapshotStore.save(snapshot)
        return snapshot
        #else
        return nil
        #endif
    }

    #if canImport(HealthKit)
    private static func sumQuantity(
        store: HKHealthStore,
        identifier: HKQuantityTypeIdentifier,
        unit: HKUnit,
        start: Date,
        end: Date
    ) async -> Double? {
        guard let type = HKQuantityType.quantityType(forIdentifier: identifier) else { return nil }
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: type,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, stats, error in
                if error != nil {
                    continuation.resume(returning: nil)
                    return
                }
                let value = stats?.sumQuantity()?.doubleValue(for: unit) ?? 0
                continuation.resume(returning: max(0, value))
            }
            store.execute(query)
        }
    }

    /// Asleep samples whose end falls on the wake day, plus staged samples that
    /// ended the evening before midnight. Good enough for a face fallback; the
    /// iPhone snapshot remains the source of truth when Connectivity delivers.
    private static func sleepHours(
        store: HKHealthStore,
        dayStart: Date,
        dayEnd: Date
    ) async -> Double? {
        guard let type = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else { return nil }
        let windowStart = dayStart.addingTimeInterval(-18 * 3600)
        let predicate = HKQuery.predicateForSamples(
            withStart: windowStart,
            end: dayEnd,
            options: .strictEndDate
        )
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: type,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            ) { _, samples, error in
                if error != nil {
                    continuation.resume(returning: nil)
                    return
                }
                let asleep = Set([
                    HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue,
                    HKCategoryValueSleepAnalysis.asleepCore.rawValue,
                    HKCategoryValueSleepAnalysis.asleepDeep.rawValue,
                    HKCategoryValueSleepAnalysis.asleepREM.rawValue,
                    HKCategoryValueSleepAnalysis.asleep.rawValue
                ])
                var seconds: TimeInterval = 0
                for sample in samples as? [HKCategorySample] ?? [] {
                    guard asleep.contains(sample.value) else { continue }
                    let clippedStart = max(sample.startDate, windowStart)
                    let clippedEnd = min(sample.endDate, dayEnd)
                    seconds += max(0, clippedEnd.timeIntervalSince(clippedStart))
                }
                continuation.resume(returning: max(0, seconds / 3600))
            }
            store.execute(query)
        }
    }
    #endif
}
