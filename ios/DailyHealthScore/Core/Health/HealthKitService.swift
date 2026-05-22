import Foundation
import HealthKit

struct HealthDayMetrics: Equatable {
    var sleepHours: Double
    var fiberGrams: Double
    var exerciseMinutes: Double
}

enum HealthKitError: LocalizedError {
    case unavailable
    case unauthorized
    case queryFailed(String)

    var errorDescription: String? {
        switch self {
        case .unavailable: return "Health data is not available on this device."
        case .unauthorized: return "Allow Daily Health Score to read Sleep, Fiber, and Exercise in Settings → Health."
        case .queryFailed(let detail): return detail
        }
    }
}

final class HealthKitService {
    let store = HKHealthStore()

    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    func requestAuthorization() async throws {
        guard isAvailable else { throw HealthKitError.unavailable }
        guard let sleep = HKObjectType.categoryType(forIdentifier: .sleepAnalysis),
              let fiber = HKObjectType.quantityType(forIdentifier: .dietaryFiber),
              let exercise = HKObjectType.quantityType(forIdentifier: .appleExerciseTime) else {
            throw HealthKitError.unavailable
        }
        try await store.requestAuthorization(toShare: [], read: [sleep, fiber, exercise])
    }

    func fetchMetrics(forDateKey dateKey: String) async throws -> HealthDayMetrics {
        guard isAvailable else { throw HealthKitError.unavailable }
        guard let dayStart = DateHelpers.date(from: dateKey) else {
            throw HealthKitError.queryFailed("Invalid date.")
        }
        let calendar = Calendar.current
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart)!
        async let sleepHours = fetchSleepHours(dayStart: dayStart, dayEnd: dayEnd, calendar: calendar)
        async let fiberGrams = fetchFiberGrams(dayStart: dayStart, dayEnd: dayEnd)
        async let exerciseMinutes = fetchExerciseMinutes(dayStart: dayStart, dayEnd: dayEnd)
        return try await HealthDayMetrics(
            sleepHours: sleepHours,
            fiberGrams: fiberGrams,
            exerciseMinutes: exerciseMinutes
        )
    }

    /// Sleep attributed to the wake calendar day. The HealthKit query fetches
    /// every asleep sub-sample from any source in a wide window around the
    /// wake day; `SleepAttribution` does the rest — grouping sub-samples into
    /// sessions, attributing whole sessions to the day in which they ENDED,
    /// merging overlapping intervals across sources, and clipping to the
    /// safety window.
    ///
    /// This is the single source of truth for the Today score's sleep value
    /// and must stay in lockstep with `sleepDiagnostic(forDateKey:)`.
    private func fetchSleepHours(dayStart: Date, dayEnd: Date, calendar: Calendar) async throws -> Double {
        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else {
            throw HealthKitError.unavailable
        }
        // Window: 6 PM previous day through 6 PM wake day. Wide enough to
        // capture late wake-ups (sleep-in days, recovery sleep, etc.) and
        // matches what SleepAttribution clips to by default.
        let windowStart = calendar.date(byAdding: .hour, value: -6, to: dayStart)!
        let windowEnd = calendar.date(byAdding: .hour, value: 18, to: dayStart)!
        let predicate = HKQuery.predicateForSamples(withStart: windowStart, end: windowEnd, options: .strictStartDate)

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: sleepType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            ) { _, samples, error in
                if let error {
                    continuation.resume(throwing: HealthKitError.queryFailed(error.localizedDescription))
                    return
                }
                let categories = (samples as? [HKCategorySample]) ?? []
                let intervals: [SleepInterval] = categories.compactMap { sample in
                    guard HealthKitService.asleepCategoryValues.contains(sample.value) else { return nil }
                    return SleepInterval(start: sample.startDate, end: sample.endDate)
                }
                let hours = SleepAttribution.attributedHours(
                    intervals: intervals,
                    dayStart: dayStart,
                    calendar: calendar
                )
                continuation.resume(returning: hours)
            }
            store.execute(query)
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
