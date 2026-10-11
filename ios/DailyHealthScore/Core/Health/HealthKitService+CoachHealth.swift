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
            facts.days = await dailyRange(.heartRate, unit: HKUnit.count().unitDivided(by: .minute()), window: window)
        case .restingHeartRate:
            facts.days = await dailyAverage(.restingHeartRate, unit: HKUnit.count().unitDivided(by: .minute()), window: window)
        case .walkingHeartRate:
            facts.days = await dailyAverage(.walkingHeartRateAverage, unit: HKUnit.count().unitDivided(by: .minute()), window: window)
        case .bloodOxygen:
            facts.days = await dailyPercent(.oxygenSaturation, window: window)
        case .respiratoryRate:
            facts.days = await dailyAverage(.respiratoryRate, unit: HKUnit.count().unitDivided(by: .minute()), window: window)
        case .standMinutes:
            facts.days = await dailyTotal(.appleStandTime, unit: .minute(), window: window)
        case .daylight:
            facts.days = await dailyTotal(.timeInDaylight, unit: .minute(), window: window)
        case .distance:
            facts.days = await dailyTotal(.distanceWalkingRunning, unit: .meter(), window: window)
        case .wristTemperature:
            facts.days = await dailyAverage(.appleSleepingWristTemperature, unit: .degreeCelsius(), window: window)
        case .bloodPressure:
            facts.days = await bloodPressure(window: window)
        case .cardioFitness:
            let vo2 = HKUnit.literUnit(with: .milli).unitDivided(by: .gramUnit(with: .kilo)).unitDivided(by: .minute())
            let samples = await quantityHistory(.vo2Max, unit: vo2, window: window)
            facts.days = samples.days
            facts.latest = samples.latest
        case .running:
            facts.runs = await runs(window: window)
        }
        return facts
    }

    private func dailyRange(
        _ identifier: HKQuantityTypeIdentifier,
        unit: HKUnit,
        window: DayWindow
    ) async -> [CoachHealthDayValue] {
        let stats = await statistics(identifier, options: [.discreteAverage, .discreteMin, .discreteMax], window: window)
        return stats.compactMap { date, stat in
            let low = stat.minimumQuantity()?.doubleValue(for: unit)
            let high = stat.maximumQuantity()?.doubleValue(for: unit)
            let average = stat.averageQuantity()?.doubleValue(for: unit)
            guard low != nil || high != nil || average != nil else { return nil }
            return CoachHealthDayValue(
                dateKey: DateHelpers.localDateKey(from: date),
                low: low,
                high: high,
                average: average
            )
        }.sorted { $0.dateKey < $1.dateKey }
    }

    private func dailyAverage(
        _ identifier: HKQuantityTypeIdentifier,
        unit: HKUnit,
        window: DayWindow
    ) async -> [CoachHealthDayValue] {
        let stats = await statistics(identifier, options: .discreteAverage, window: window)
        return stats.compactMap { date, stat in
            guard let average = stat.averageQuantity()?.doubleValue(for: unit) else { return nil }
            return CoachHealthDayValue(dateKey: DateHelpers.localDateKey(from: date), average: average)
        }.sorted { $0.dateKey < $1.dateKey }
    }

    private func dailyPercent(_ identifier: HKQuantityTypeIdentifier, window: DayWindow) async -> [CoachHealthDayValue] {
        let unit = HKUnit.percent()
        let stats = await statistics(identifier, options: [.discreteAverage, .discreteMin, .discreteMax], window: window)
        return stats.compactMap { date, stat in
            func percent(_ quantity: HKQuantity?) -> Double? {
                guard let quantity else { return nil }
                let value = quantity.doubleValue(for: unit)
                return value <= 1 ? value * 100 : value
            }
            let low = percent(stat.minimumQuantity())
            let high = percent(stat.maximumQuantity())
            let average = percent(stat.averageQuantity())
            guard low != nil || high != nil || average != nil else { return nil }
            return CoachHealthDayValue(dateKey: DateHelpers.localDateKey(from: date), low: low, high: high, average: average)
        }.sorted { $0.dateKey < $1.dateKey }
    }

    private func dailyTotal(
        _ identifier: HKQuantityTypeIdentifier,
        unit: HKUnit,
        window: DayWindow
    ) async -> [CoachHealthDayValue] {
        let stats = await statistics(identifier, options: .cumulativeSum, window: window)
        return stats.compactMap { date, stat in
            guard let total = stat.sumQuantity()?.doubleValue(for: unit), total > 0 else { return nil }
            return CoachHealthDayValue(dateKey: DateHelpers.localDateKey(from: date), total: total)
        }.sorted { $0.dateKey < $1.dateKey }
    }

    private func statistics(
        _ identifier: HKQuantityTypeIdentifier,
        options: HKStatisticsOptions,
        window: DayWindow
    ) async -> [(Date, HKStatistics)] {
        guard let type = HKQuantityType.quantityType(forIdentifier: identifier) else { return [] }
        let predicate = HKQuery.predicateForSamples(withStart: window.start, end: window.end, options: .strictStartDate)
        return await withCheckedContinuation { continuation in
            let query = HKStatisticsCollectionQuery(
                quantityType: type,
                quantitySamplePredicate: predicate,
                options: options,
                anchorDate: window.start,
                intervalComponents: DateComponents(day: 1)
            )
            query.initialResultsHandler = { _, collection, _ in
                var rows: [(Date, HKStatistics)] = []
                collection?.enumerateStatistics(from: window.start, to: window.end) { stat, _ in
                    rows.append((stat.startDate, stat))
                }
                continuation.resume(returning: rows)
            }
            store.execute(query)
        }
    }

    private func bloodPressure(window: DayWindow) async -> [CoachHealthDayValue] {
        guard let correlation = HKCorrelationType.correlationType(forIdentifier: .bloodPressure),
              let systolicType = HKQuantityType.quantityType(forIdentifier: .bloodPressureSystolic),
              let diastolicType = HKQuantityType.quantityType(forIdentifier: .bloodPressureDiastolic) else {
            return []
        }
        let predicate = HKQuery.predicateForSamples(withStart: window.start, end: window.end, options: .strictStartDate)
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
        let samples: [HKCorrelation] = await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: correlation, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sort]) { _, results, _ in
                continuation.resume(returning: (results as? [HKCorrelation]) ?? [])
            }
            store.execute(query)
        }
        let unit = HKUnit.millimeterOfMercury()
        var byDay: [String: [CoachHealthPressureReading]] = [:]
        for sample in samples {
            let systolic = (sample.objects(for: systolicType).first as? HKQuantitySample)?.quantity.doubleValue(for: unit)
            let diastolic = (sample.objects(for: diastolicType).first as? HKQuantitySample)?.quantity.doubleValue(for: unit)
            guard let systolic, let diastolic else { continue }
            let key = DateHelpers.localDateKey(from: sample.startDate)
            let reading = CoachHealthPressureReading(
                timeLabel: sample.startDate.formatted(date: .omitted, time: .shortened),
                systolic: systolic,
                diastolic: diastolic
            )
            byDay[key, default: []].append(reading)
        }
        return byDay.keys.sorted().map { CoachHealthDayValue(dateKey: $0, readings: byDay[$0] ?? []) }
    }

    private func quantityHistory(
        _ identifier: HKQuantityTypeIdentifier,
        unit: HKUnit,
        window: DayWindow
    ) async -> (days: [CoachHealthDayValue], latest: CoachHealthLatest?) {
        guard let type = HKQuantityType.quantityType(forIdentifier: identifier) else { return ([], nil) }
        let inWindow = await samples(type: type, start: window.start, end: window.end, limit: HKObjectQueryNoLimit)
        let newest = await samples(type: type, start: .distantPast, end: window.end, limit: 1)
        let days = inWindow.map {
            CoachHealthDayValue(
                dateKey: DateHelpers.localDateKey(from: $0.startDate),
                average: $0.quantity.doubleValue(for: unit)
            )
        }.sorted { $0.dateKey < $1.dateKey }
        let latest = newest.first.map {
            CoachHealthLatest(value: $0.quantity.doubleValue(for: unit), dateKey: DateHelpers.localDateKey(from: $0.startDate))
        }
        return (days, latest)
    }

    private func runs(window: DayWindow) async -> [CoachHealthRun] {
        let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            HKQuery.predicateForSamples(withStart: window.start, end: window.end, options: .strictStartDate),
            HKQuery.predicateForWorkouts(with: .running)
        ])
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
        let workouts: [HKWorkout] = await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: HKObjectType.workoutType(), predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sort]) { _, results, _ in
                continuation.resume(returning: (results as? [HKWorkout]) ?? [])
            }
            store.execute(query)
        }
        var runs: [CoachHealthRun] = []
        for workout in workouts {
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
        return runs
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

    private func samples(type: HKQuantityType, start: Date, end: Date, limit: Int) async -> [HKQuantitySample] {
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: limit, sortDescriptors: [sort]) { _, results, _ in
                continuation.resume(returning: (results as? [HKQuantitySample]) ?? [])
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
