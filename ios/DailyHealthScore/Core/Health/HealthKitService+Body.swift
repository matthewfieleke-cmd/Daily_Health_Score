import Foundation
import HealthKit

extension HealthKitService {
    /// Weight, height, and BMI from Health for the trailing window. Missing
    /// permissions or data resolve to an empty result, never an error.
    func fetchBodyMeasurements(days: Int = 120, now: Date = Date()) async -> BodyMeasurements {
        guard isAvailable else { return BodyMeasurements() }
        let start = Calendar.current.date(byAdding: .day, value: -days, to: now) ?? now
        var measurements = BodyMeasurements()

        if let weightType = HKQuantityType.quantityType(forIdentifier: .bodyMass) {
            let samples = await quantitySamples(type: weightType, start: start, end: now, limit: HKObjectQueryNoLimit)
            measurements.weights = samples.map {
                BodyWeightSample(date: $0.startDate, kilograms: $0.quantity.doubleValue(for: .gramUnit(with: .kilo)))
            }
        }
        if let heightType = HKQuantityType.quantityType(forIdentifier: .height) {
            // Height rarely changes; take the most recent reading of any age.
            let samples = await quantitySamples(type: heightType, start: .distantPast, end: now, limit: 1)
            measurements.heightMeters = samples.first?.quantity.doubleValue(for: .meter())
        }
        if let bmiType = HKQuantityType.quantityType(forIdentifier: .bodyMassIndex) {
            let samples = await quantitySamples(type: bmiType, start: start, end: now, limit: 1)
            if let sample = samples.first {
                measurements.latestBMISample = sample.quantity.doubleValue(for: .count())
                measurements.latestBMIDate = sample.startDate
            }
        }
        return measurements
    }

    /// Newest first.
    private func quantitySamples(
        type: HKQuantityType,
        start: Date,
        end: Date,
        limit: Int
    ) async -> [HKQuantitySample] {
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: type,
                predicate: predicate,
                limit: limit,
                sortDescriptors: [sort]
            ) { _, results, _ in
                continuation.resume(returning: (results as? [HKQuantitySample]) ?? [])
            }
            store.execute(query)
        }
    }
}
