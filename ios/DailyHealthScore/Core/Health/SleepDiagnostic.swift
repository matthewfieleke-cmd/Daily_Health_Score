import Foundation
import HealthKit

/// A single asleep sample as returned by the HealthKit query, with
/// human-readable labels for the diagnostic view.
struct SleepDiagnosticSample: Identifiable {
    let id = UUID()
    let stage: String          // "Core", "REM", "Deep", "Unspecified", "Awake", "In Bed", etc.
    let isAsleep: Bool         // true if this sample counts toward our total
    let sourceName: String     // e.g. "Apple Watch", "iPhone", "AutoSleep"
    let start: Date
    let end: Date

    var durationSeconds: TimeInterval { end.timeIntervalSince(start) }
}

/// A snapshot of everything our app sees from HealthKit for a single day's
/// sleep query. Used by the in-app diagnostic to make it easy to compare
/// against the Apple Health Sleep detail view.
struct SleepDiagnostic {
    let dateKey: String
    let dayStart: Date
    let windowStart: Date
    let windowEnd: Date
    let allSamples: [SleepDiagnosticSample]
    let attributedHours: Double

    var asleepSamples: [SleepDiagnosticSample] { allSamples.filter(\.isAsleep) }

    var sumOfAllAsleepDurationsHours: Double {
        asleepSamples.reduce(0.0) { $0 + $1.durationSeconds } / 3600.0
    }

    var sourcesSeen: [String] {
        Array(Set(allSamples.map(\.sourceName))).sorted()
    }
}

extension HealthKitService {
    /// Fetches every sleep-analysis sample our query would see for the wake
    /// day at `dateKey`, plus computes the attributed total. Used by the
    /// in-app diagnostic screen to expose exactly what's going into the
    /// score so we can compare it against Apple Health's own display.
    func sleepDiagnostic(forDateKey dateKey: String) async throws -> SleepDiagnostic {
        guard isAvailable else { throw HealthKitError.unavailable }
        guard let dayStart = DateHelpers.date(from: dateKey) else {
            throw HealthKitError.queryFailed("Invalid date.")
        }
        let calendar = Calendar.current
        let windowStart = calendar.date(byAdding: .hour, value: -6, to: dayStart)!
        let windowEnd = calendar.date(byAdding: .hour, value: 18, to: dayStart)!

        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else {
            throw HealthKitError.unavailable
        }
        let predicate = HKQuery.predicateForSamples(withStart: windowStart, end: windowEnd, options: .strictStartDate)

        let samples = try await sleepSamples(matching: predicate, type: sleepType)
        let mapped = samples.map { sample in
            SleepDiagnosticSample(
                stage: Self.stageName(for: sample.value),
                isAsleep: Self.asleepCategoryValues.contains(sample.value),
                sourceName: sample.sourceRevision.source.name,
                start: sample.startDate,
                end: sample.endDate
            )
        }
        .sorted { $0.start < $1.start }

        // Recompute the attributed total using the same code path as the
        // production app so the diagnostic value matches Today's score.
        let intervals: [SleepInterval] = mapped
            .filter(\.isAsleep)
            .map { SleepInterval(start: $0.start, end: $0.end) }
        let attributed = SleepAttribution.attributedHours(
            intervals: intervals,
            dayStart: dayStart,
            calendar: calendar
        )

        return SleepDiagnostic(
            dateKey: dateKey,
            dayStart: dayStart,
            windowStart: windowStart,
            windowEnd: windowEnd,
            allSamples: mapped,
            attributedHours: attributed
        )
    }

    /// All `HKCategoryValueSleepAnalysis` values our scorer counts as "asleep".
    static let asleepCategoryValues: Set<Int> = [
        HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue,
        HKCategoryValueSleepAnalysis.asleepCore.rawValue,
        HKCategoryValueSleepAnalysis.asleepDeep.rawValue,
        HKCategoryValueSleepAnalysis.asleepREM.rawValue,
    ]

    /// Human-friendly name for an `HKCategoryValueSleepAnalysis` raw value.
    static func stageName(for rawValue: Int) -> String {
        switch rawValue {
        case HKCategoryValueSleepAnalysis.inBed.rawValue: return "In Bed"
        case HKCategoryValueSleepAnalysis.awake.rawValue: return "Awake"
        case HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue: return "Asleep"
        case HKCategoryValueSleepAnalysis.asleepCore.rawValue: return "Core"
        case HKCategoryValueSleepAnalysis.asleepDeep.rawValue: return "Deep"
        case HKCategoryValueSleepAnalysis.asleepREM.rawValue: return "REM"
        default: return "Unknown(\(rawValue))"
        }
    }

    private func sleepSamples(
        matching predicate: NSPredicate,
        type: HKCategoryType
    ) async throws -> [HKCategorySample] {
        try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: type,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            ) { _, samples, error in
                if let error {
                    continuation.resume(throwing: HealthKitError.queryFailed(error.localizedDescription))
                    return
                }
                continuation.resume(returning: (samples as? [HKCategorySample]) ?? [])
            }
            store.execute(query)
        }
    }
}
