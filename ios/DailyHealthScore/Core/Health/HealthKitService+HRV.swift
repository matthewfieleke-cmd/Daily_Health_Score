import Foundation
import HealthKit

extension HealthKitService {
    struct SleepFetchBundle {
        var hours: Double
        var asleepIntervals: [SleepInterval]
        var windowStart: Date
        var windowEnd: Date
    }

    func resilientSleepBundle(dayStart: Date, calendar: Calendar) async -> SleepFetchBundle? {
        try? await fetchSleepBundle(dayStart: dayStart, calendar: calendar)
    }

    func resilientOptional(_ operation: () async throws -> Double?) async -> Double? {
        do {
            return try await operation()
        } catch {
            return nil
        }
    }

    func fetchSleepBundle(dayStart: Date, calendar: Calendar) async throws -> SleepFetchBundle {
        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else {
            throw HealthKitError.unavailable
        }
        // Window: 6 PM previous day through 6 PM wake day — matches SleepAttribution.
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
                    guard Self.asleepCategoryValues.contains(sample.value) else { return nil }
                    return SleepInterval(start: sample.startDate, end: sample.endDate)
                }
                let hours = SleepAttribution.attributedHours(
                    intervals: intervals,
                    dayStart: dayStart,
                    calendar: calendar
                )
                continuation.resume(
                    returning: SleepFetchBundle(
                        hours: hours,
                        asleepIntervals: intervals,
                        windowStart: windowStart,
                        windowEnd: windowEnd
                    )
                )
            }
            store.execute(query)
        }
    }

    func fetchSleepHRVSDNNMs(
        asleepIntervals: [SleepInterval],
        dayStart: Date,
        windowStart: Date,
        windowEnd: Date,
        calendar: Calendar
    ) async throws -> Double? {
        guard let hrvType = HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN) else {
            throw HealthKitError.unavailable
        }
        let predicate = HKQuery.predicateForSamples(withStart: windowStart, end: windowEnd, options: .strictStartDate)
        let unit = HKUnit.secondUnit(with: .milli)

        let samples: [HRVSample] = try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: hrvType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            ) { _, results, error in
                if let error {
                    continuation.resume(throwing: HealthKitError.queryFailed(error.localizedDescription))
                    return
                }
                let mapped = (results as? [HKQuantitySample])?.map { sample in
                    HRVSample(
                        timestamp: sample.startDate,
                        sdnnMilliseconds: sample.quantity.doubleValue(for: unit)
                    )
                } ?? []
                continuation.resume(returning: mapped)
            }
            store.execute(query)
        }

        return SleepHRVAttribution.averageSDNNMs(
            samples: samples,
            asleepIntervals: asleepIntervals,
            dayStart: dayStart,
            calendar: calendar
        )
    }
}
