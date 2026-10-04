import Foundation
import HealthKit
import UIKit

struct HealthDayMetrics: Equatable {
    var sleepHours: Double
    var fiberGrams: Double
    var exerciseMinutes: Double
    var stepCount: Double = 0
    var sleepHrvSDNNMs: Double? = nil
    var sleepHasUnsettledSession: Bool = false

    /// Health owns sleep, fiber grams, steps, and exercise minutes.
    /// Food-group servings stay on the saved record and are copied back on sync.
    var dailyMetrics: DailyMetrics {
        DailyMetrics(
            sleepHours: sleepHours,
            fiberGrams: fiberGrams,
            exerciseMinutes: exerciseMinutes,
            stepCount: stepCount
        )
    }
}

enum HealthKitError: LocalizedError {
    case unavailable
    case unauthorized
    case queryFailed(String)

    var errorDescription: String? {
        switch self {
        case .unavailable: return "Health data is not available on this device."
        case .unauthorized: return "Allow Daily Health Score to read Sleep, Fiber, Exercise Minutes, Steps, and Heart Rate Variability in Settings → Health."
        case .queryFailed(let detail): return detail
        }
    }
}

final class HealthKitService {
    static let shared = HealthKitService()

    let store = HKHealthStore()
    private var observerQueries: [HKObserverQuery] = []
    private var didStartObservers = false

    private init() {}

    /// Set from `AppState`. May be nil for a moment at process launch.
    var onBackgroundChange: (@Sendable (HealthChangeKind) async -> Void)?

    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    func requestAuthorization() async throws {
        guard isAvailable else { throw HealthKitError.unavailable }
        guard let sleep = HKObjectType.categoryType(forIdentifier: .sleepAnalysis),
              let fiber = HKObjectType.quantityType(forIdentifier: .dietaryFiber),
              let exercise = HKObjectType.quantityType(forIdentifier: .appleExerciseTime),
              let steps = HKObjectType.quantityType(forIdentifier: .stepCount),
              let hrv = HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN) else {
            throw HealthKitError.unavailable
        }
        var readTypes: Set<HKObjectType> = [sleep, fiber, exercise, steps, hrv, HKObjectType.workoutType()]
        // Weight, height, BMI, age, and sex feed the Coach only; the score never
        // sees them. Age and sex keep the Coach from guessing either.
        for identifier in [HKQuantityTypeIdentifier.bodyMass, .height, .bodyMassIndex] {
            if let type = HKObjectType.quantityType(forIdentifier: identifier) {
                readTypes.insert(type)
            }
        }
        for identifier in [HKCharacteristicTypeIdentifier.dateOfBirth, .biologicalSex] {
            if let type = HKObjectType.characteristicType(forIdentifier: identifier) {
                readTypes.insert(type)
            }
        }
        try await store.requestAuthorization(toShare: [], read: readTypes)
    }

    /// Wakes the app when sleep, fiber, exercise minutes, steps, or a workout land in
    /// Health so today can be rebuilt and pushed to the Watch without opening
    /// the iPhone UI.
    func startBackgroundDelivery() async {
        guard isAvailable else { return }
        guard let sleep = HKObjectType.categoryType(forIdentifier: .sleepAnalysis),
              let fiber = HKObjectType.quantityType(forIdentifier: .dietaryFiber),
              let exercise = HKObjectType.quantityType(forIdentifier: .appleExerciseTime),
              let steps = HKObjectType.quantityType(forIdentifier: .stepCount) else {
            return
        }
        await enableDelivery(for: sleep, frequency: .immediate)
        await enableDelivery(for: fiber, frequency: .immediate)
        await enableDelivery(for: exercise, frequency: .immediate)
        await enableDelivery(for: steps, frequency: .immediate)
        await enableDelivery(for: HKObjectType.workoutType(), frequency: .immediate)
        guard !didStartObservers else { return }
        didStartObservers = true
        observe(sleep, kind: .sleep)
        observe(fiber, kind: .fiber)
        observe(exercise, kind: .exerciseMinutes)
        observe(steps, kind: .steps)
        observe(HKObjectType.workoutType(), kind: .workout)
    }

    private func enableDelivery(for type: HKObjectType, frequency: HKUpdateFrequency) async {
        do {
            try await store.enableBackgroundDelivery(for: type, frequency: frequency)
        } catch {
            // Delivery is best-effort; opening the app still syncs.
        }
    }

    private func observe(_ type: HKSampleType, kind: HealthChangeKind) {
        let query = HKObserverQuery(sampleType: type, predicate: nil) { [weak self] _, completionHandler, error in
            let failed = error != nil
            HealthBackgroundTask.run {
                guard !failed else { return }
                await self?.deliverBackgroundChange(kind)
            } completion: {
                completionHandler()
            }
        }
        observerQueries.append(query)
        store.execute(query)
    }

    /// Waits briefly for `AppState` to attach a handler on a HealthKit launch.
    private func deliverBackgroundChange(_ kind: HealthChangeKind) async {
        for _ in 0 ..< 50 {
            if let onBackgroundChange {
                await onBackgroundChange(kind)
                return
            }
            try? await Task.sleep(for: .milliseconds(200))
        }
    }

    /// Reads sleep, fiber, exercise, and optional sleep HRV for a day. Score
    /// metrics resolve to 0 if their query fails; HRV resolves to nil when absent.
    func fetchMetrics(forDateKey dateKey: String) async throws -> HealthDayMetrics {
        guard isAvailable else { throw HealthKitError.unavailable }
        guard let dayStart = DateHelpers.date(from: dateKey) else {
            throw HealthKitError.queryFailed("Invalid date.")
        }
        let calendar = Calendar.current
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart)!

        async let sleepBundle = resilientSleepBundle(dayStart: dayStart, calendar: calendar)
        async let fiberGrams = fiberGramsOrZero(dayStart: dayStart, dayEnd: dayEnd)
        async let exerciseMinutes = exerciseMinutesOrZero(dayStart: dayStart, dayEnd: dayEnd)
        async let stepCount = stepCountOrZero(dayStart: dayStart, dayEnd: dayEnd)

        let bundle = await sleepBundle
        let sleepHrvSDNNMs = await sleepHRVOrNil(bundle: bundle, dayStart: dayStart, calendar: calendar)

        return await HealthDayMetrics(
            sleepHours: bundle?.hours ?? 0,
            fiberGrams: fiberGrams,
            exerciseMinutes: exerciseMinutes,
            stepCount: stepCount,
            sleepHrvSDNNMs: sleepHrvSDNNMs,
            sleepHasUnsettledSession: bundle?.hasUnsettledSession ?? false
        )
    }

    /// A failed query is 0, so one missing metric still yields a scored day.
    private func fiberGramsOrZero(dayStart: Date, dayEnd: Date) async -> Double {
        do { return try await fetchFiberGrams(dayStart: dayStart, dayEnd: dayEnd) } catch { return 0 }
    }

    private func exerciseMinutesOrZero(dayStart: Date, dayEnd: Date) async -> Double {
        do { return try await fetchExerciseMinutes(dayStart: dayStart, dayEnd: dayEnd) } catch { return 0 }
    }

    private func stepCountOrZero(dayStart: Date, dayEnd: Date) async -> Double {
        do { return try await fetchStepCount(dayStart: dayStart, dayEnd: dayEnd) } catch { return 0 }
    }

    private func sleepHRVOrNil(bundle: SleepFetchBundle?, dayStart: Date, calendar: Calendar) async -> Double? {
        guard let bundle else { return nil }
        do {
            return try await fetchSleepHRVSDNNMs(
                asleepIntervals: bundle.asleepIntervals,
                dayStart: dayStart,
                windowStart: bundle.windowStart,
                windowEnd: bundle.windowEnd,
                calendar: calendar
            )
        } catch {
            return nil
        }
    }

    private func fetchFiberGrams(dayStart: Date, dayEnd: Date) async throws -> Double {
        try await sumQuantity(
            identifier: .dietaryFiber,
            unit: .gram(),
            dayStart: dayStart,
            dayEnd: dayEnd
        )
    }

    private func fetchExerciseMinutes(dayStart: Date, dayEnd: Date) async throws -> Double {
        try await sumQuantity(
            identifier: .appleExerciseTime,
            unit: .minute(),
            dayStart: dayStart,
            dayEnd: dayEnd
        )
    }

    private func fetchStepCount(dayStart: Date, dayEnd: Date) async throws -> Double {
        try await sumQuantity(
            identifier: .stepCount,
            unit: .count(),
            dayStart: dayStart,
            dayEnd: dayEnd
        )
    }

    private func sumQuantity(
        identifier: HKQuantityTypeIdentifier,
        unit: HKUnit,
        dayStart: Date,
        dayEnd: Date
    ) async throws -> Double {
        guard let type = HKQuantityType.quantityType(forIdentifier: identifier) else {
            throw HealthKitError.unavailable
        }
        let predicate = HKQuery.predicateForSamples(withStart: dayStart, end: dayEnd, options: .strictStartDate)
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: type,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, stats, error in
                if let error {
                    continuation.resume(throwing: HealthKitError.queryFailed(error.localizedDescription))
                    return
                }
                let value = stats?.sumQuantity()?.doubleValue(for: unit) ?? 0
                continuation.resume(returning: max(0, value))
            }
            store.execute(query)
        }
    }
}

/// Holds a HealthKit observer wake long enough to read today and push the Watch.
enum HealthBackgroundTask {
    static func run(
        _ work: @escaping @Sendable () async -> Void,
        completion: @escaping () -> Void
    ) {
        Task { @MainActor in
            var finished = false
            let finish = {
                guard !finished else { return }
                finished = true
                completion()
            }
            var taskId = UIBackgroundTaskIdentifier.invalid
            taskId = UIApplication.shared.beginBackgroundTask(withName: "dhs.health-sync") {
                finish()
                if taskId != .invalid {
                    UIApplication.shared.endBackgroundTask(taskId)
                    taskId = .invalid
                }
            }
            await work()
            finish()
            if taskId != .invalid {
                UIApplication.shared.endBackgroundTask(taskId)
            }
        }
    }
}
