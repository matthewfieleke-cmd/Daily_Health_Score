import Foundation
import HealthKit

extension HealthKitService {
    /// Latest workout end on the local calendar day, if any.
    func latestWorkoutEndDate(on dateKey: String, now: Date = Date()) async -> Date? {
        guard isAvailable else { return nil }
        guard let dayStart = DateHelpers.date(from: dateKey) else { return nil }
        let predicate = HKQuery.predicateForSamples(
            withStart: dayStart,
            end: now,
            options: .strictStartDate
        )
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: HKObjectType.workoutType(),
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)]
            ) { _, samples, _ in
                let latest = (samples as? [HKWorkout])?.map(\.endDate).max()
                continuation.resume(returning: latest)
            }
            store.execute(query)
        }
    }
}
