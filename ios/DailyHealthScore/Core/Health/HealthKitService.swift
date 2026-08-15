import Foundation
import HealthKit

struct HealthDayMetrics: Equatable {
    var sleepHours: Double
    var fiberGrams: Double
    var exerciseMinutes: Double
    var sleepHrvSDNNMs: Double? = nil
}

enum HealthKitError: LocalizedError {
    case unavailable
    case unauthorized
    case queryFailed(String)

    var errorDescription: String? {
        switch self {
        case .unavailable: return "Health data is not available on this device."
        case .unauthorized: return "Allow Daily Health Score to read Sleep, Fiber, Exercise, and Heart Rate Variability in Settings → Health."
        case .queryFailed(let detail): return detail
        }
    }
}

final class HealthKitService {
    let store = HKHealthStore()
    private var observerQueries: [HKObserverQuery] = []
    private var didStartBackgroundDelivery = false

    /// Called on a HealthKit background queue when new samples arrive.
    var onBackgroundChange: (@Sendable () -> Void)?

    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    func requestAuthorization() async throws {
        guard isAvailable else { throw HealthKitError.unavailable }
        guard let sleep = HKObjectType.categoryType(forIdentifier: .sleepAnalysis),
              let fiber = HKObjectType.quantityType(forIdentifier: .dietaryFiber),
              let exercise = HKObjectType.quantityType(forIdentifier: .appleExerciseTime),
              let hrv = HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN) else {
            throw HealthKitError.unavailable
        }
        try await store.requestAuthorization(toShare: [], read: [sleep, fiber, exercise, hrv])
    }

    /// Wakes the app when sleep, fiber, or exercise land in Health so today can
    /// be rebuilt and pushed to the Watch without opening the iPhone app.
    func startBackgroundDelivery() async {
        guard isAvailable, !didStartBackgroundDelivery else { return }
        guard let sleep = HKObjectType.categoryType(forIdentifier: .sleepAnalysis),
              let fiber = HKObjectType.quantityType(forIdentifier: .dietaryFiber),
              let exercise = HKObjectType.quantityType(forIdentifier: .appleExerciseTime) else {
            return
        }
        didStartBackgroundDelivery = true
        await enableDelivery(for: sleep, frequency: .hourly)
        await enableDelivery(for: fiber, frequency: .immediate)
        await enableDelivery(for: exercise, frequency: .immediate)
        observe(sleep)
        observe(fiber)
        observe(exercise)
    }

    private func enableDelivery(for type: HKObjectType, frequency: HKUpdateFrequency) async {
        do {
            try await store.enableBackgroundDelivery(for: type, frequency: frequency)
        } catch {
            // Delivery is best-effort; scheduled pace checks still catch a silent day.
        }
    }

    private func observe(_ type: HKSampleType) {
        let query = HKObserverQuery(sampleType: type, predicate: nil) { [weak self] _, completionHandler, error in
            if error == nil {
                self?.onBackgroundChange?()
            }
            completionHandler()
        }
        observerQueries.append(query)
        store.execute(query)
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
        async let fiberGrams = resilient { try await self.fetchFiberGrams(dayStart: dayStart, dayEnd: dayEnd) }
        async let exerciseMinutes = resilient {
            try await self.fetchExerciseMinutes(dayStart: dayStart, dayEnd: dayEnd)
        }

        let bundle = await sleepBundle
        let sleepHrvSDNNMs = await resilientOptional {
            guard let bundle else { return nil }
            return try await self.fetchSleepHRVSDNNMs(
                asleepIntervals: bundle.asleepIntervals,
                dayStart: dayStart,
                windowStart: bundle.windowStart,
                windowEnd: bundle.windowEnd,
                calendar: calendar
            )
        }

        return await HealthDayMetrics(
            sleepHours: bundle?.hours ?? 0,
            fiberGrams: fiberGrams,
            exerciseMinutes: exerciseMinutes,
            sleepHrvSDNNMs: sleepHrvSDNNMs
        )
    }

    /// Runs a single metric query, returning 0 instead of throwing so a partial
    /// Health read (e.g. no fiber logged yet today) still yields a scored day.
    private func resilient(_ operation: () async throws -> Double) async -> Double {
        do {
            return try await operation()
        } catch {
            return 0
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
