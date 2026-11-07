import Foundation
import HealthKit

extension HealthKitService {
    /// Live Apple Health readings for the advisor. Missing permission or a
    /// missing day comes back as no record. Nothing here is written onto the
    /// score.
    func coachHealthFacts(
        measures: [CoachHealthMeasure],
        startKey: String,
        endKey: String,
        todayKey: String
    ) async -> CoachHealthFacts {
        guard isAvailable, let window = dayWindow(startKey: startKey, endKey: endKey) else {
            let empty = measures.map {
                CoachHealthMeasureFacts(measure: $0)
            }
            return CoachHealthReport.facts(measures: empty, startKey: startKey, endKey: endKey, todayKey: todayKey)
        }
        let distanceMetric = await prefersMetricDistance()
        let fahrenheit = Locale.current.measurementSystem == .us
        var loaded: [CoachHealthMeasureFacts] = []
        for measure in measures {
            loaded.append(await load(
                measure,
                window: window,
                distanceUsesMetric: distanceMetric,
                temperatureUsesFahrenheit: fahrenheit
            ))
        }
        return CoachHealthReport.facts(measures: loaded, startKey: startKey, endKey: endKey, todayKey: todayKey)
    }

    func coachHealthChart(measure: CoachHealthMeasure, endingOn todayKey: String = DateHelpers.localDateKey(), days: Int = 7) async -> CoachHealthChart? {
        let start = DateHelpers.addDays(to: todayKey, days: -(max(days, 1) - 1)) ?? todayKey
        return await coachHealthFacts(measures: [measure], startKey: start, endKey: todayKey, todayKey: todayKey).chart
    }

    private struct DayWindow {
        var start: Date
        var end: Date
        var calendar: Calendar
    }

    private func dayWindow(startKey: String, endKey: String) -> DayWindow? {
        let calendar = Calendar.current
        guard let start = DateHelpers.date(from: startKey),
              let endDay = DateHelpers.date(from: endKey),
              let end = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: endDay)) else {
            return nil
        }
        return DayWindow(start: calendar.startOfDay(for: start), end: end, calendar: calendar)
    }

    private func load(
        _ measure: CoachHealthMeasure,
        window: DayWindow,
        distanceUsesMetric: Bool,
        temperatureUsesFahrenheit: Bool
    ) async -> CoachHealthMeasureFacts {
        var facts = CoachHealthMeasureFacts(
            measure: measure,
            distanceUsesMetric: distanceUsesMetric,
            temperatureUsesFahrenheit: temperatureUsesFahrenheit
        )
        switch measure {
        case .heartRate:
            let read = await heartRateDays(window: window)
            facts.days = read.days
            facts.unavailable = read.failed
        case .restingHeartRate:
            let read = await dailyAverage(.restingHeartRate, unit: Self.beatsPerMinute, window: window)
            facts.days = read.days
            facts.unavailable = read.failed
        case .walkingHeartRate:
            let read = await dailyAverage(.walkingHeartRateAverage, unit: Self.beatsPerMinute, window: window)
            facts.days = read.days
            facts.unavailable = read.failed
        case .bloodOxygen:
            let read = await dailyPercent(.oxygenSaturation, window: window)
            facts.days = read.days
            facts.unavailable = read.failed
        case .respiratoryRate:
            let read = await dailyAverage(.respiratoryRate, unit: Self.beatsPerMinute, window: window)
            facts.days = read.days
            facts.unavailable = read.failed
        case .standMinutes:
            let read = await dailyTotal(.appleStandTime, unit: .minute(), window: window)
            facts.days = read.days
            facts.unavailable = read.failed
        case .daylight:
            let read = await dailyTotal(.timeInDaylight, unit: .minute(), window: window)
            facts.days = read.days
            facts.unavailable = read.failed
        case .distance:
            let read = await dailyTotal(.distanceWalkingRunning, unit: .meter(), window: window)
            facts.days = read.days
            facts.unavailable = read.failed
        case .wristTemperature:
            let read = await dailyAverage(.appleSleepingWristTemperature, unit: .degreeCelsius(), window: window)
            facts.days = read.days
            facts.unavailable = read.failed
        case .bloodPressure:
            let read = await bloodPressure(window: window)
            facts.days = read.days
            facts.unavailable = read.failed
        case .cardioFitness:
            let vo2 = HKUnit.literUnit(with: .milli).unitDivided(by: .gramUnit(with: .kilo)).unitDivided(by: .minute())
            var history = await quantityHistory(.vo2Max, unit: vo2, window: window)
            if history.days.isEmpty && history.latest == nil {
                let averaged = await dailyAverage(.vo2Max, unit: vo2, window: window)
                if !averaged.days.isEmpty {
                    history.days = averaged.days
                }
                let stillEmpty = history.days.isEmpty && history.latest == nil
                history.failed = stillEmpty && history.failed && averaged.failed
            }
            facts.days = history.days
            facts.latest = history.latest
            facts.unavailable = history.failed
        case .running:
            let read = await runs(window: window)
            facts.runs = read.runs
            facts.unavailable = read.failed
        }
        return facts
    }

    private static let beatsPerMinute = HKUnit.count().unitDivided(by: .minute())

    private func dailyRange(
        _ identifier: HKQuantityTypeIdentifier,
        unit: HKUnit,
        window: DayWindow
    ) async -> (days: [CoachHealthDayValue], failed: Bool) {
        let read = await dailyQuantities(identifier, unit: unit, options: [.discreteAverage, .discreteMin, .discreteMax], window: window)
        let days = read.days.compactMap { day -> CoachHealthDayValue? in
            guard day.low != nil || day.high != nil || day.average != nil else { return nil }
            return CoachHealthDayValue(dateKey: DateHelpers.localDateKey(from: day.start), low: day.low, high: day.high, average: day.average)
        }.sorted { $0.dateKey < $1.dateKey }
        return (days, read.failed)
    }

    private func dailyAverage(
        _ identifier: HKQuantityTypeIdentifier,
        unit: HKUnit,
        window: DayWindow
    ) async -> (days: [CoachHealthDayValue], failed: Bool) {
        let read = await dailyQuantities(identifier, unit: unit, options: .discreteAverage, window: window)
        let days = read.days.compactMap { day -> CoachHealthDayValue? in
            guard let average = day.average else { return nil }
            return CoachHealthDayValue(dateKey: DateHelpers.localDateKey(from: day.start), average: average)
        }.sorted { $0.dateKey < $1.dateKey }
        return (days, read.failed)
    }

    private func dailyPercent(_ identifier: HKQuantityTypeIdentifier, window: DayWindow) async -> (days: [CoachHealthDayValue], failed: Bool) {
        let read = await dailyQuantities(identifier, unit: .percent(), options: [.discreteAverage, .discreteMin, .discreteMax], window: window)
        let days = read.days.compactMap { day -> CoachHealthDayValue? in
            func percent(_ value: Double?) -> Double? {
                guard let value else { return nil }
                return value <= 1 ? value * 100 : value
            }
            let low = percent(day.low)
            let high = percent(day.high)
            let average = percent(day.average)
            guard low != nil || high != nil || average != nil else { return nil }
            return CoachHealthDayValue(dateKey: DateHelpers.localDateKey(from: day.start), low: low, high: high, average: average)
        }.sorted { $0.dateKey < $1.dateKey }
        return (days, read.failed)
    }

    private func dailyTotal(
        _ identifier: HKQuantityTypeIdentifier,
        unit: HKUnit,
        window: DayWindow
    ) async -> (days: [CoachHealthDayValue], failed: Bool) {
        let read = await dailyQuantities(identifier, unit: unit, options: .cumulativeSum, window: window)
        let days = read.days.compactMap { day -> CoachHealthDayValue? in
            guard let total = day.sum, total > 0 else { return nil }
            return CoachHealthDayValue(dateKey: DateHelpers.localDateKey(from: day.start), total: total)
        }.sorted { $0.dateKey < $1.dateKey }
        return (days, read.failed)
    }

    private struct DayQuantities: Sendable {
        var start: Date
        var low: Double?
        var high: Double?
        var average: Double?
        var sum: Double?
        var failed: Bool
    }

    /// One statistics collection over a long window can come back as a single
    /// interval, for heart rate and for the other daily measures. A failed
    /// read, or at most one day in a longer window, is checked one calendar
    /// day at a time. Heart rate still has a sample fallback after that.
    private func dailyQuantities(
        _ identifier: HKQuantityTypeIdentifier,
        unit: HKUnit,
        options: HKStatisticsOptions,
        window: DayWindow
    ) async -> (days: [DayQuantities], failed: Bool) {
        guard let type = HKQuantityType.quantityType(forIdentifier: identifier) else { return ([], true) }
        let bounds = dayBounds(in: window)
        let collected = await statisticsCollection(type: type, unit: unit, options: options, window: window)
        let collapsed = bounds.count > 1 && collected.days.count <= 1
        guard collected.failed || collapsed else { return collected }
        let verified = await perDayQuantities(type: type, unit: unit, options: options, bounds: bounds)
        if verified.days.count > collected.days.count || (collected.failed && !verified.failed) {
            return verified
        }
        if collected.failed { return verified }
        return collected
    }

    private func heartRateDays(window: DayWindow) async -> (days: [CoachHealthDayValue], failed: Bool) {
        var read = await dailyRange(.heartRate, unit: Self.beatsPerMinute, window: window)
        guard dayBounds(in: window).count > 1, read.days.count <= 1 else { return read }
        let sampled = await heartRateFromSamples(window: window)
        if sampled.days.count > read.days.count {
            read = sampled
        } else if read.days.isEmpty {
            read.failed = read.failed && sampled.failed
        }
        return read
    }

    /// Plain average of the samples in each calendar day. Used when the
    /// statistics query reports at most one day of a longer window.
    private func heartRateFromSamples(window: DayWindow) async -> (days: [CoachHealthDayValue], failed: Bool) {
        guard let type = HKQuantityType.quantityType(forIdentifier: .heartRate) else { return ([], true) }
        let read = await samples(type: type, start: window.start, end: window.end, limit: HKObjectQueryNoLimit)
        if read.failed { return ([], true) }
        struct Bucket {
            var low: Double
            var high: Double
            var sum: Double
            var count: Int
        }
        var buckets: [String: Bucket] = [:]
        for sample in read.samples {
            let value = sample.quantity.doubleValue(for: Self.beatsPerMinute)
            let key = DateHelpers.localDateKey(from: sample.startDate)
            if var bucket = buckets[key] {
                bucket.low = min(bucket.low, value)
                bucket.high = max(bucket.high, value)
                bucket.sum += value
                bucket.count += 1
                buckets[key] = bucket
            } else {
                buckets[key] = Bucket(low: value, high: value, sum: value, count: 1)
            }
        }
        let days = buckets.map { key, bucket in
            CoachHealthDayValue(
                dateKey: key,
                low: bucket.low,
                high: bucket.high,
                average: bucket.sum / Double(bucket.count)
            )
        }.sorted { $0.dateKey < $1.dateKey }
        return (days, false)
    }

    private func dayBounds(in window: DayWindow) -> [(start: Date, end: Date)] {
        var bounds: [(Date, Date)] = []
        var cursor = window.start
        while cursor < window.end && bounds.count < 400 {
            guard let next = window.calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            bounds.append((cursor, min(next, window.end)))
            cursor = next
        }
        return bounds
    }

    private func statisticsCollection(
        type: HKQuantityType,
        unit: HKUnit,
        options: HKStatisticsOptions,
        window: DayWindow
    ) async -> (days: [DayQuantities], failed: Bool) {
        var interval = DateComponents()
        interval.calendar = window.calendar
        interval.day = 1
        let predicate = HKQuery.predicateForSamples(withStart: window.start, end: window.end, options: .strictStartDate)
        return await withCheckedContinuation { continuation in
            let query = HKStatisticsCollectionQuery(
                quantityType: type,
                quantitySamplePredicate: predicate,
                options: options,
                anchorDate: window.start,
                intervalComponents: interval
            )
            query.initialResultsHandler = { _, collection, error in
                guard error == nil, let collection else {
                    continuation.resume(returning: ([], true))
                    return
                }
                var days: [DayQuantities] = []
                collection.enumerateStatistics(from: window.start, to: window.end) { stat, _ in
                    let quantities = Self.quantities(stat, unit: unit)
                    guard quantities.hasValue else { return }
                    days.append(DayQuantities(
                        start: stat.startDate,
                        low: quantities.low,
                        high: quantities.high,
                        average: quantities.average,
                        sum: quantities.sum,
                        failed: false
                    ))
                }
                continuation.resume(returning: (days, false))
            }
            store.execute(query)
        }
    }

    private func perDayQuantities(
        type: HKQuantityType,
        unit: HKUnit,
        options: HKStatisticsOptions,
        bounds: [(start: Date, end: Date)]
    ) async -> (days: [DayQuantities], failed: Bool) {
        var days: [DayQuantities] = []
        var failures = 0
        for bound in bounds {
            let outcome = await dayStatistics(type: type, unit: unit, options: options, start: bound.start, end: bound.end)
            if outcome.failed {
                failures += 1
                continue
            }
            guard outcome.hasValue else { continue }
            days.append(DayQuantities(
                start: bound.start,
                low: outcome.low,
                high: outcome.high,
                average: outcome.average,
                sum: outcome.sum,
                failed: false
            ))
        }
        let failed = !bounds.isEmpty && failures == bounds.count
        return (days, failed)
    }

    private struct QuantityValues {
        var low: Double? = nil
        var high: Double? = nil
        var average: Double? = nil
        var sum: Double? = nil
        var failed: Bool = false

        var hasValue: Bool {
            low != nil || high != nil || average != nil || (sum ?? 0) > 0
        }
    }

    private func dayStatistics(
        type: HKQuantityType,
        unit: HKUnit,
        options: HKStatisticsOptions,
        start: Date,
        end: Date
    ) async -> QuantityValues {
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: options) { _, stats, error in
                guard error == nil, let stats else {
                    continuation.resume(returning: QuantityValues(failed: true))
                    return
                }
                var values = Self.quantities(stats, unit: unit)
                values.failed = false
                continuation.resume(returning: values)
            }
            store.execute(query)
        }
    }

    private static func quantities(_ stats: HKStatistics, unit: HKUnit) -> QuantityValues {
        QuantityValues(
            low: stats.minimumQuantity()?.doubleValue(for: unit),
            high: stats.maximumQuantity()?.doubleValue(for: unit),
            average: stats.averageQuantity()?.doubleValue(for: unit),
            sum: stats.sumQuantity()?.doubleValue(for: unit)
        )
    }

    /// Withings writes two ordinary samples, systolic and diastolic, at the
    /// same time. A date filter on the query was returning none of them, so
    /// this reads every saved sample and keeps the ones in the requested days.
    /// The paired record is read the same way, with no date filter.
    private func bloodPressure(window: DayWindow) async -> (days: [CoachHealthDayValue], failed: Bool) {
        guard let correlationType = HKCorrelationType.correlationType(forIdentifier: .bloodPressure),
              let systolicType = HKQuantityType.quantityType(forIdentifier: .bloodPressureSystolic),
              let diastolicType = HKQuantityType.quantityType(forIdentifier: .bloodPressureDiastolic) else {
            return ([], true)
        }
        let unit = HKUnit.millimeterOfMercury()
        let systolic = await everySample(of: systolicType)
        let diastolic = await everySample(of: diastolicType)
        let paired = BloodPressureReadings.pair(
            systolic: systolic.samples.map { BloodPressureReadings.Sample(date: $0.startDate, value: $0.quantity.doubleValue(for: unit)) },
            diastolic: diastolic.samples.map { BloodPressureReadings.Sample(date: $0.startDate, value: $0.quantity.doubleValue(for: unit)) }
        )
        let correlated = await everyCuffRecord(type: correlationType, systolicType: systolicType, diastolicType: diastolicType, unit: unit)
        let shown = BloodPressureReadings.inWindow(
            BloodPressureReadings.merged(correlated.readings, paired),
            start: window.start,
            end: window.end
        )
        let failed = shown.isEmpty && systolic.failed && diastolic.failed && correlated.failed
        return (dayValues(from: shown), failed)
    }

    private func everySample(of type: HKQuantityType) async -> (samples: [HKQuantitySample], failed: Bool) {
        await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: type, predicate: nil, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, results, error in
                let samples = (results ?? []).compactMap { $0 as? HKQuantitySample }
                continuation.resume(returning: (samples, samples.isEmpty && error != nil))
            }
            store.execute(query)
        }
    }

    private func everyCuffRecord(
        type: HKCorrelationType,
        systolicType: HKQuantityType,
        diastolicType: HKQuantityType,
        unit: HKUnit
    ) async -> (readings: [BloodPressureReadings.Reading], failed: Bool) {
        await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: type, predicate: nil, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, results, error in
                let readings = (results ?? []).compactMap { sample -> BloodPressureReadings.Reading? in
                    guard let record = sample as? HKCorrelation else { return nil }
                    let systolic = (record.objects(for: systolicType).first as? HKQuantitySample)?.quantity.doubleValue(for: unit)
                    let diastolic = (record.objects(for: diastolicType).first as? HKQuantitySample)?.quantity.doubleValue(for: unit)
                    guard let systolic, let diastolic else { return nil }
                    return BloodPressureReadings.Reading(date: record.startDate, systolic: systolic, diastolic: diastolic)
                }
                continuation.resume(returning: (readings, readings.isEmpty && error != nil))
            }
            store.execute(query)
        }
    }

    private func dayValues(from readings: [BloodPressureReadings.Reading]) -> [CoachHealthDayValue] {
        var byDay: [String: [CoachHealthPressureReading]] = [:]
        for reading in readings {
            let key = DateHelpers.localDateKey(from: reading.date)
            byDay[key, default: []].append(
                CoachHealthPressureReading(
                    timeLabel: reading.date.formatted(date: .omitted, time: .shortened),
                    systolic: reading.systolic,
                    diastolic: reading.diastolic
                )
            )
        }
        return byDay.keys.sorted().map { CoachHealthDayValue(dateKey: $0, readings: byDay[$0] ?? []) }
    }

    private func quantityHistory(
        _ identifier: HKQuantityTypeIdentifier,
        unit: HKUnit,
        window: DayWindow
    ) async -> (days: [CoachHealthDayValue], latest: CoachHealthLatest?, failed: Bool) {
        guard let type = HKQuantityType.quantityType(forIdentifier: identifier) else { return ([], nil, true) }
        let inWindow = await samples(type: type, start: window.start, end: window.end, limit: HKObjectQueryNoLimit)
        let newest = await samples(type: type, start: HealthKitService.earliestSampleDate, end: window.end, limit: 1)
        let days = inWindow.samples.map {
            CoachHealthDayValue(
                dateKey: DateHelpers.localDateKey(from: $0.startDate),
                average: $0.quantity.doubleValue(for: unit)
            )
        }.sorted { $0.dateKey < $1.dateKey }
        let latest = newest.samples.first.map {
            CoachHealthLatest(value: $0.quantity.doubleValue(for: unit), dateKey: DateHelpers.localDateKey(from: $0.startDate))
        }
        let failed = days.isEmpty && latest == nil && inWindow.failed && newest.failed
        return (days, latest, failed)
    }

    private func runs(window: DayWindow) async -> (runs: [CoachHealthRun], failed: Bool) {
        let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            HKQuery.predicateForSamples(withStart: window.start, end: window.end, options: .strictStartDate),
            HKQuery.predicateForWorkouts(with: .running)
        ])
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
        let workouts: (samples: [HKWorkout], failed: Bool) = await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: HKObjectType.workoutType(), predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sort]) { _, results, error in
                let samples = (results ?? []).compactMap { $0 as? HKWorkout }
                continuation.resume(returning: (samples, samples.isEmpty && error != nil))
            }
            store.execute(query)
        }
        if workouts.failed { return ([], true) }
        var runs: [CoachHealthRun] = []
        for workout in workouts.samples {
            let speed = await workoutAverage(.runningSpeed, unit: HKUnit.meter().unitDivided(by: .second()), workout: workout)
            let power = await workoutAverage(.runningPower, unit: .watt(), workout: workout)
            let heart = await workoutAverage(.heartRate, unit: HKUnit.count().unitDivided(by: .minute()), workout: workout)
            runs.append(CoachHealthRun(
                dateKey: DateHelpers.localDateKey(from: workout.startDate),
                timeLabel: workout.startDate.formatted(date: .omitted, time: .shortened),
                durationMinutes: workout.duration / 60,
                distanceMeters: workout.totalDistance?.doubleValue(for: .meter()),
                averageSpeedMetersPerSecond: speed,
                averagePowerWatts: power,
                averageHeartRate: heart
            ))
        }
        return (runs, false)
    }

    private func workoutAverage(_ identifier: HKQuantityTypeIdentifier, unit: HKUnit, workout: HKWorkout) async -> Double? {
        guard let type = HKQuantityType.quantityType(forIdentifier: identifier) else { return nil }
        let predicate = HKQuery.predicateForObjects(from: workout)
        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: .discreteAverage) { _, stats, _ in
                continuation.resume(returning: stats?.averageQuantity()?.doubleValue(for: unit))
            }
            store.execute(query)
        }
    }

    private func samples(
        type: HKQuantityType,
        start: Date,
        end: Date,
        limit: Int,
        options: HKQueryOptions = .strictStartDate
    ) async -> (samples: [HKQuantitySample], failed: Bool) {
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: options)
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: limit, sortDescriptors: [sort]) { _, results, error in
                let samples = (results ?? []).compactMap { $0 as? HKQuantitySample }
                continuation.resume(returning: (samples, samples.isEmpty && error != nil))
            }
            store.execute(query)
        }
    }

    private func prefersMetricDistance() async -> Bool {
        guard let type = HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning),
              let units = try? await store.preferredUnits(for: [type]),
              let unit = units[type] else {
            return Locale.current.measurementSystem == .metric
        }
        return unit != HKUnit.mile()
    }
}
