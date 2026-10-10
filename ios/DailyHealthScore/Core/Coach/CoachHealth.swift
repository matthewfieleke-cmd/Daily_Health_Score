import Foundation

/// Apple Health records the advisor can look up. They are not part of the
/// Daily Health Score. A missing day stays a missing day.
enum CoachHealthMeasure: String, CaseIterable, Identifiable, Sendable {
    case heartRate
    case restingHeartRate
    case bloodOxygen
    case bloodPressure
    case cardioFitness
    case standMinutes
    case distance
    case daylight
    case respiratoryRate
    case walkingHeartRate
    case wristTemperature
    case running

    var id: String { rawValue }

    var title: String {
        switch self {
        case .heartRate: return "Heart rate"
        case .restingHeartRate: return "Resting heart rate"
        case .bloodOxygen: return "Blood oxygen"
        case .bloodPressure: return "Blood pressure"
        case .cardioFitness: return "Cardio fitness"
        case .standMinutes: return "Stand minutes"
        case .distance: return "Walking and running distance"
        case .daylight: return "Time in daylight"
        case .respiratoryRate: return "Respiratory rate"
        case .walkingHeartRate: return "Walking heart rate"
        case .wristTemperature: return "Overnight wrist temperature"
        case .running: return "Running"
        }
    }

    static var names: String {
        allCases.map(\.rawValue).joined(separator: ", ")
    }

    /// One measure from a chart field or a single token.
    static func parseOne(_ raw: String) -> CoachHealthMeasure? {
        let text = raw
            .lowercased()
            .replacingOccurrences(of: "_", with: " ")
            .split(whereSeparator: { $0.isWhitespace || $0 == "-" })
            .joined(separator: " ")
        switch text {
        case "resting heart rate", "restingheartrate", "resting hr", "rhr":
            return .restingHeartRate
        case "walking heart rate", "walking heart rate average", "walkingheartrate":
            return .walkingHeartRate
        case "heart rate", "heartrate", "hr":
            return .heartRate
        case "blood oxygen", "oxygen", "spo2", "oxygen saturation":
            return .bloodOxygen
        case "blood pressure", "bp", "pressure":
            return .bloodPressure
        case "cardio fitness", "vo2", "vo2 max", "vo2max":
            return .cardioFitness
        case "stand", "stand minutes", "stand time", "standminutes":
            return .standMinutes
        case "distance", "walking distance", "walking running distance", "walking and running distance":
            return .distance
        case "daylight", "time in daylight", "sunlight":
            return .daylight
        case "respiratory rate", "respiration", "breathing rate":
            return .respiratoryRate
        case "wrist temperature", "wrist temp", "temperature":
            return .wristTemperature
        case "running", "run", "runs", "running speed", "running power":
            return .running
        default:
            return nil
        }
    }

    static func parseList(_ raw: String) -> [CoachHealthMeasure] {
        var seen = Set<CoachHealthMeasure>()
        return raw.split(separator: ",").compactMap { piece in
            guard let measure = parseOne(String(piece)) else { return nil }
            return seen.insert(measure).inserted ? measure : nil
        }
    }
}

struct CoachHealthPressureReading: Equatable, Sendable {
    var timeLabel: String
    var systolic: Double
    var diastolic: Double
}

struct CoachHealthDayValue: Equatable, Sendable {
    var dateKey: String
    var low: Double?
    var high: Double?
    var average: Double?
    /// Minutes, or meters for distance.
    var total: Double?
    var readings: [CoachHealthPressureReading] = []
}

struct CoachHealthRun: Equatable, Sendable {
    var dateKey: String
    var timeLabel: String
    var durationMinutes: Double
    var distanceMeters: Double?
    var averageSpeedMetersPerSecond: Double?
    var averagePowerWatts: Double?
    var averageHeartRate: Double?
}

struct CoachHealthLatest: Equatable, Sendable {
    var value: Double
    var dateKey: String
}

struct CoachHealthMeasureFacts: Equatable, Sendable {
    var measure: CoachHealthMeasure
    var days: [CoachHealthDayValue] = []
    var runs: [CoachHealthRun] = []
    var latest: CoachHealthLatest?
    var distanceUsesMetric: Bool = true
    var temperatureUsesFahrenheit: Bool = false
}

struct CoachHealthChartPoint: Equatable, Identifiable, Sendable {
    var dateKey: String
    var label: String
    var value: Double
    var id: String { dateKey }
}

struct CoachHealthChart: Equatable, Sendable {
    var title: String
    var points: [CoachHealthChartPoint]
    var headline: String
    var caption: String
}

struct CoachHealthFacts: Equatable, Sendable {
    var text: String
    var hasRecord: Bool
    var chart: CoachHealthChart?
}

enum CoachHealthReport {
    /// Past this, a day-by-day list becomes a shape: the average of days that
    /// have a record, and how many days do not.
    static let maxListedDays = 31

    static func facts(
        measures: [CoachHealthMeasureFacts],
        startKey: String,
        endKey: String,
        todayKey: String
    ) -> CoachHealthFacts {
        let sections = measures.map { section($0, startKey: startKey, endKey: endKey) }
        let text = sections.map(\.text).joined(separator: "\n\n")
            + "\nToday is \(DateHelpers.formatDisplayDate(todayKey))."
        let chart = measures.count == 1 ? sections.first?.chart : nil
        return CoachHealthFacts(
            text: text,
            hasRecord: sections.contains { $0.hasRecord },
            chart: chart
        )
    }

    private struct Section {
        var text: String
        var hasRecord: Bool
        var chart: CoachHealthChart?
    }

    private static func section(_ facts: CoachHealthMeasureFacts, startKey: String, endKey: String) -> Section {
        let span = spanLabel(startKey: startKey, endKey: endKey)
        switch facts.measure {
        case .running:
            return runningSection(facts, span: span, startKey: startKey, endKey: endKey)
        case .cardioFitness:
            return fitnessSection(facts, span: span, singleDay: startKey == endKey)
        case .bloodPressure:
            return pressureSection(facts, span: span, singleDay: startKey == endKey)
        default:
            return dailySection(facts, span: span, singleDay: startKey == endKey, startKey: startKey, endKey: endKey)
        }
    }

    private static func dailySection(
        _ facts: CoachHealthMeasureFacts,
        span: String,
        singleDay: Bool,
        startKey: String,
        endKey: String
    ) -> Section {
        let recorded = facts.days.filter { valueLine(facts.measure, day: $0, facts: facts) != nil }
        let chart = chart(for: facts, recorded: recorded, startKey: startKey, endKey: endKey)
        if singleDay {
            let day = facts.days.first
            let line = day.flatMap { valueLine(facts.measure, day: $0, facts: facts) }
            let text = "\(facts.measure.title), \(span): \(line ?? "no record")."
            return Section(text: text, hasRecord: line != nil, chart: chart)
        }
        if recorded.isEmpty {
            return Section(text: "\(facts.measure.title), \(span): no record.", hasRecord: false, chart: nil)
        }
        if recorded.count > maxListedDays {
            let summary = summaryLine(facts.measure, days: recorded, facts: facts)
            let missing = max(facts.days.count - recorded.count, 0)
            var text = "\(facts.measure.title), \(span): \(summary)"
            if missing > 0 {
                text += " \(missing) \(missing == 1 ? "day has" : "days have") no record."
            }
            return Section(text: text, hasRecord: true, chart: chart)
        }
        var lines = ["\(facts.measure.title), \(span):"]
        let byKey = Dictionary(uniqueKeysWithValues: facts.days.map { ($0.dateKey, $0) })
        for key in keys(from: startKey, through: endKey) {
            guard let day = byKey[key] else { continue }
            if let line = valueLine(facts.measure, day: day, facts: facts) {
                lines.append("- \(DateHelpers.formatDisplayDate(key)): \(line)")
            }
        }
        let missing = keys(from: startKey, through: endKey).filter { key in
            guard let day = byKey[key] else { return true }
            return valueLine(facts.measure, day: day, facts: facts) == nil
        }.count
        if missing > 0 {
            lines.append("\(missing) \(missing == 1 ? "day has" : "days have") no record.")
        }
        return Section(text: lines.joined(separator: "\n"), hasRecord: true, chart: chart)
    }

    private static func pressureSection(_ facts: CoachHealthMeasureFacts, span: String, singleDay: Bool) -> Section {
        let readings = facts.days.flatMap { day in
            day.readings.map { (day.dateKey, $0) }
        }
        guard !readings.isEmpty else {
            return Section(text: "Blood pressure, \(span): no record.", hasRecord: false, chart: nil)
        }
        if readings.count > 24 {
            let systolics = readings.map(\.1.systolic)
            let diastolics = readings.map(\.1.diastolic)
            let text = "Blood pressure, \(span): \(readings.count) readings, systolic \(whole(systolics.min() ?? 0))–\(whole(systolics.max() ?? 0)) mmHg, diastolic \(whole(diastolics.min() ?? 0))–\(whole(diastolics.max() ?? 0)) mmHg."
            return Section(text: text, hasRecord: true, chart: pressureChart(facts, readings: readings))
        }
        var lines = ["Blood pressure, \(span):"]
        for (key, reading) in readings {
            let when = singleDay ? reading.timeLabel : "\(DateHelpers.formatDisplayDate(key)) \(reading.timeLabel)"
            lines.append("- \(when): \(whole(reading.systolic))/\(whole(reading.diastolic)) mmHg")
        }
        return Section(text: lines.joined(separator: "\n"), hasRecord: true, chart: pressureChart(facts, readings: readings))
    }

    private static func fitnessSection(_ facts: CoachHealthMeasureFacts, span: String, singleDay: Bool) -> Section {
        let recorded = facts.days.filter { $0.average != nil }
        var lines: [String] = []
        if recorded.isEmpty {
            lines.append("Cardio fitness, \(span): no record.")
        } else if singleDay, let day = recorded.first, let value = day.average {
            lines.append("Cardio fitness, \(span): \(fitness(value)).")
        } else {
            lines.append("Cardio fitness, \(span):")
            for day in recorded {
                if let value = day.average {
                    lines.append("- \(DateHelpers.formatDisplayDate(day.dateKey)): \(fitness(value))")
                }
            }
        }
        if let latest = facts.latest, recorded.contains(where: { $0.dateKey == latest.dateKey }) == false {
            lines.append("Latest record: \(fitness(latest.value)) on \(DateHelpers.formatDisplayDate(latest.dateKey)).")
        }
        let chartDays = recorded.isEmpty ? latestChartDays(facts.latest) : recorded
        let chart = chart(for: facts, recorded: chartDays, startKey: chartDays.first?.dateKey ?? "", endKey: chartDays.last?.dateKey ?? "")
        let hasRecord = !recorded.isEmpty || facts.latest != nil
        return Section(text: lines.joined(separator: "\n"), hasRecord: hasRecord, chart: hasRecord ? chart : nil)
    }

    private static func runningSection(
        _ facts: CoachHealthMeasureFacts,
        span: String,
        startKey: String,
        endKey: String
    ) -> Section {
        guard !facts.runs.isEmpty else {
            return Section(text: "Running, \(span): no runs recorded.", hasRecord: false, chart: nil)
        }
        var lines = ["Running, \(span):"]
        for run in facts.runs {
            lines.append("- \(runLine(run, metric: facts.distanceUsesMetric))")
        }
        let chart = runChart(facts, startKey: startKey, endKey: endKey)
        return Section(text: lines.joined(separator: "\n"), hasRecord: true, chart: chart)
    }

    private static func valueLine(_ measure: CoachHealthMeasure, day: CoachHealthDayValue, facts: CoachHealthMeasureFacts) -> String? {
        switch measure {
        case .heartRate:
            return rangeLine(day, unit: "bpm")
        case .restingHeartRate, .walkingHeartRate:
            guard let average = day.average else { return nil }
            return "\(whole(average)) bpm"
        case .bloodOxygen:
            guard day.low != nil || day.high != nil || day.average != nil else { return nil }
            if let low = day.low, let high = day.high, abs(low - high) >= 0.5 {
                return "low \(whole(low))%, high \(whole(high))%"
            }
            return "\(whole(day.average ?? day.low ?? day.high ?? 0))%"
        case .standMinutes:
            guard let total = day.total else { return nil }
            return "\(whole(total)) min"
        case .distance:
            guard let meters = day.total else { return nil }
            return distance(meters, metric: facts.distanceUsesMetric)
        case .daylight:
            guard let minutes = day.total else { return nil }
            return duration(minutes: minutes)
        case .respiratoryRate:
            guard let average = day.average else { return nil }
            return String(format: "%.1f breaths/min", average)
        case .wristTemperature:
            guard let average = day.average else { return nil }
            return temperature(average, fahrenheit: facts.temperatureUsesFahrenheit)
        case .cardioFitness:
            guard let average = day.average else { return nil }
            return fitness(average)
        case .bloodPressure, .running:
            return nil
        }
    }

    private static func summaryLine(_ measure: CoachHealthMeasure, days: [CoachHealthDayValue], facts: CoachHealthMeasureFacts) -> String {
        switch measure {
        case .heartRate:
            var parts: [String] = []
            let lows = days.compactMap(\.low)
            let highs = days.compactMap(\.high)
            let averages = days.compactMap(\.average)
            if !lows.isEmpty { parts.append("low \(whole(mean(lows)))") }
            if !highs.isEmpty { parts.append("high \(whole(mean(highs)))") }
            if !averages.isEmpty { parts.append("average \(whole(mean(averages)))") }
            return "\(parts.joined(separator: " ")) bpm across \(days.count) days with a record."
        case .distance:
            let meters = days.compactMap(\.total).reduce(0, +)
            return "\(distance(meters, metric: facts.distanceUsesMetric)) across \(days.count) days with a record."
        case .standMinutes, .daylight:
            let total = days.compactMap(\.total).reduce(0, +)
            let body = measure == .daylight ? duration(minutes: total) : "\(whole(total)) min"
            return "\(body) across \(days.count) days with a record."
        default:
            let averages = days.compactMap(\.average)
            guard let first = averages.first else { return "\(days.count) days with a record." }
            return "average \(valueLine(measure, day: CoachHealthDayValue(dateKey: "", average: mean(averages)), facts: facts) ?? whole(first)) across \(days.count) days with a record."
        }
    }

    private static func rangeLine(_ day: CoachHealthDayValue, unit: String) -> String? {
        var parts: [String] = []
        if let low = day.low { parts.append("low \(whole(low))") }
        if let high = day.high { parts.append("high \(whole(high))") }
        if let average = day.average { parts.append("average \(whole(average))") }
        guard !parts.isEmpty else { return nil }
        return parts.joined(separator: " ") + " \(unit)"
    }

    private static func runLine(_ run: CoachHealthRun, metric: Bool) -> String {
        var parts = ["\(DateHelpers.formatDisplayDate(run.dateKey)) \(run.timeLabel): \(duration(minutes: run.durationMinutes))"]
        if let meters = run.distanceMeters { parts.append(distance(meters, metric: metric)) }
        if let speed = run.averageSpeedMetersPerSecond, speed > 0 { parts.append("pace \(pace(metersPerSecond: speed, metric: metric))") }
        if let watts = run.averagePowerWatts { parts.append("power \(whole(watts)) W") }
        if let heart = run.averageHeartRate { parts.append("heart rate \(whole(heart)) bpm") }
        return parts.joined(separator: ", ")
    }

    private static func chart(for facts: CoachHealthMeasureFacts, recorded: [CoachHealthDayValue], startKey: String, endKey: String) -> CoachHealthChart? {
        let points = recorded.compactMap { day -> CoachHealthChartPoint? in
            guard let value = chartValue(facts.measure, day: day, metric: facts.distanceUsesMetric, fahrenheit: facts.temperatureUsesFahrenheit) else { return nil }
            return CoachHealthChartPoint(dateKey: day.dateKey, label: weekdayLetter(day.dateKey), value: value)
        }
        guard !points.isEmpty else { return nil }
        let windowDays = keys(from: startKey, through: endKey).count
        let missing = max(windowDays - points.count, 0)
        let caption = missing > 0
            ? "\(points.count) \(points.count == 1 ? "day has" : "days have") a record. \(missing) \(missing == 1 ? "day has" : "days have") no record and \(missing == 1 ? "is" : "are") left out."
            : "\(points.count) \(points.count == 1 ? "day" : "days") with a record."
        let headline = points.count == 1
            ? (valueLine(facts.measure, day: recorded.last ?? recorded[0], facts: facts) ?? "")
            : (summaryLine(facts.measure, days: recorded, facts: facts))
        return CoachHealthChart(title: facts.measure.title, points: points, headline: headline, caption: caption)
    }

    private static func pressureChart(_ facts: CoachHealthMeasureFacts, readings: [(String, CoachHealthPressureReading)]) -> CoachHealthChart? {
        var byDay: [String: [Double]] = [:]
        for (key, reading) in readings {
            byDay[key, default: []].append(reading.systolic)
        }
        let points = byDay.keys.sorted().map { key in
            CoachHealthChartPoint(dateKey: key, label: weekdayLetter(key), value: mean(byDay[key] ?? []))
        }
        guard !points.isEmpty else { return nil }
        return CoachHealthChart(
            title: "Blood pressure",
            points: points,
            headline: "Systolic",
            caption: "\(readings.count) \(readings.count == 1 ? "reading" : "readings"). Each reading is in the text."
        )
    }

    private static func runChart(_ facts: CoachHealthMeasureFacts, startKey: String, endKey: String) -> CoachHealthChart? {
        var byDay: [String: Double] = [:]
        for run in facts.runs {
            byDay[run.dateKey, default: 0] += run.distanceMeters ?? 0
        }
        let points = byDay.keys.sorted().compactMap { key -> CoachHealthChartPoint? in
            let meters = byDay[key] ?? 0
            guard meters > 0 else { return nil }
            let shown = facts.distanceUsesMetric ? meters / 1_000 : meters / 1_609.344
            return CoachHealthChartPoint(dateKey: key, label: weekdayLetter(key), value: shown)
        }
        guard !points.isEmpty else { return nil }
        let unit = facts.distanceUsesMetric ? "km" : "mi"
        return CoachHealthChart(
            title: "Running",
            points: points,
            headline: "\(String(format: "%.1f", points.map(\.value).reduce(0, +))) \(unit)",
            caption: "Distance of runs. Days with no run are left out."
        )
    }

    private static func latestChartDays(_ latest: CoachHealthLatest?) -> [CoachHealthDayValue] {
        guard let latest else { return [] }
        return [CoachHealthDayValue(dateKey: latest.dateKey, average: latest.value)]
    }

    private static func chartValue(_ measure: CoachHealthMeasure, day: CoachHealthDayValue, metric: Bool, fahrenheit: Bool) -> Double? {
        switch measure {
        case .heartRate, .restingHeartRate, .walkingHeartRate, .respiratoryRate, .cardioFitness:
            return day.average
        case .bloodOxygen:
            return day.average ?? day.low ?? day.high
        case .standMinutes, .daylight:
            return day.total
        case .distance:
            guard let meters = day.total else { return nil }
            return metric ? meters / 1_000 : meters / 1_609.344
        case .wristTemperature:
            guard let average = day.average else { return nil }
            return fahrenheit ? average * 1.8 : average
        case .bloodPressure, .running:
            return nil
        }
    }

    private static func spanLabel(startKey: String, endKey: String) -> String {
        if startKey == endKey { return DateHelpers.formatDisplayDate(startKey) }
        return "\(DateHelpers.formatDisplayDate(startKey)) through \(DateHelpers.formatDisplayDate(endKey))"
    }

    private static func keys(from startKey: String, through endKey: String) -> [String] {
        var keys: [String] = []
        var cursor = startKey
        while cursor <= endKey, keys.count < 400 {
            keys.append(cursor)
            guard let next = DateHelpers.addDays(to: cursor, days: 1) else { break }
            cursor = next
        }
        return keys
    }

    private static func weekdayLetter(_ key: String) -> String {
        guard let date = DateHelpers.date(from: key) else { return "" }
        return date.formatted(.dateTime.weekday(.narrow))
    }

    private static func whole(_ value: Double) -> String {
        String(format: "%.0f", value.rounded())
    }

    private static func mean(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        return values.reduce(0, +) / Double(values.count)
    }

    private static func fitness(_ value: Double) -> String {
        String(format: "%.1f mL/kg/min", value)
    }

    private static func distance(_ meters: Double, metric: Bool) -> String {
        if metric {
            return String(format: meters >= 10_000 ? "%.1f km" : "%.2f km", meters / 1_000)
        }
        return String(format: "%.2f mi", meters / 1_609.344)
    }

    private static func duration(minutes: Double) -> String {
        let rounded = Int(minutes.rounded())
        if rounded >= 60 {
            return "\(rounded / 60) hr \(rounded % 60) min"
        }
        return "\(rounded) min"
    }

    private static func pace(metersPerSecond: Double, metric: Bool) -> String {
        let seconds = (metric ? 1_000 : 1_609.344) / metersPerSecond
        let wholeSeconds = Int(seconds.rounded())
        return String(format: "%d:%02d /%@", wholeSeconds / 60, wholeSeconds % 60, metric ? "km" : "mi")
    }

    private static func temperature(_ celsius: Double, fahrenheit: Bool) -> String {
        if fahrenheit {
            return String(format: "%+.1f °F", celsius * 1.8)
        }
        return String(format: "%+.1f °C", celsius)
    }
}
