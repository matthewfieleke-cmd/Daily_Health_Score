import Foundation

/// One color on the Home card. A blank panel has no topic and no finding.
enum CoachInsightTone: String, Codable, CaseIterable, Identifiable, Sendable {
    case green
    case yellow
    case red

    var id: String { rawValue }

    var name: String {
        switch self {
        case .green: return "Green"
        case .yellow: return "Yellow"
        case .red: return "Red"
        }
    }

    /// The bold lead on the advice bullet.
    var actionLead: String {
        switch self {
        case .green: return "Maintain the Green."
        case .yellow: return "Monitor the Yellow."
        case .red: return "Improve the Red."
        }
    }
}

struct CoachInsightPanel: Codable, Equatable, Sendable, Identifiable {
    var tone: CoachInsightTone
    var topic: String = ""
    var finding: String = ""
    var advice: String = ""

    var id: String { tone.rawValue }

    var isBlank: Bool {
        topic.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || finding.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// The finding and the advice, for the reply chat.
    var spoken: String {
        var line = "\(tone.name), \(topic). \(finding)"
        let action = advice.trimmingCharacters(in: .whitespacesAndNewlines)
        if !action.isEmpty {
            line += " \(tone.actionLead) \(action)"
        }
        return line
    }
}

/// A finished workout inside the 90-day window. Today is already excluded.
struct CoachWorkoutSummary: Equatable, Sendable {
    var dateKey: String
    var activity: String
    var durationMinutes: Double
}

/// The Apple Health record the Home card is written from. Today is excluded.
/// A metric needs three readings before it is included. A metric with more
/// readings is not ranked above one with fewer.
struct CoachInsightPacket: Equatable, Sendable {
    var text: String
    var metricCount: Int

    var isEmpty: Bool { metricCount == 0 }
}

enum CoachInsightRecord {
    static let minimumPoints = 3
    static let needsDataSentence = "Start populating Apple Health metrics to obtain your Health Insights"

    static func make(
        records: [DailyRecord],
        settings: UserSettings,
        weight: BodyTrend?,
        goals: [SMARTGoal],
        measures: [CoachHealthMeasureFacts],
        workouts: [CoachWorkoutSummary],
        todayKey: String
    ) -> CoachInsightPacket {
        guard let endKey = DateHelpers.addDays(to: todayKey, days: -1) else {
            return CoachInsightPacket(text: "", metricCount: 0)
        }
        var sections: [String] = []
        if let sleep = dailySection(
            name: "Sleep",
            points: records.compactMap { record in
                guard record.date < todayKey, record.sleepHours > 0 else { return nil }
                return (record.date, record.sleepHours)
            },
            endKey: endKey,
            line: { average in "average \(CompletedTrendBuilder.formatSleep(average))" },
            compared: { difference in
                compared(difference, threshold: 10.0 / 60.0) { hours in
                    CompletedTrendBuilder.formatSleep(hours)
                }
            }
        ) {
            sections.append(sleep)
        }
        if let nutrition = nutritionSection(records: records, settings: settings, todayKey: todayKey, endKey: endKey) {
            sections.append(nutrition)
        }
        if let movement = movementSection(records: records, settings: settings, todayKey: todayKey, endKey: endKey) {
            sections.append(movement)
        }
        if let weight = weightSection(weight) {
            sections.append(weight)
        }
        let runningIncluded = measures.contains { facts in
            facts.measure == .running && runningCount(facts, endKey: endKey) >= minimumPoints
        }
        for summary in workoutSections(workouts, endKey: endKey, skipRunning: runningIncluded) {
            sections.append(summary)
        }
        for facts in measures {
            if let section = measureSection(facts, endKey: endKey) {
                sections.append(section)
            }
        }
        guard !sections.isEmpty else {
            return CoachInsightPacket(text: "", metricCount: 0)
        }
        let body = """
        Finished days only. Today is excluded. A metric is listed once it has at least \(minimumPoints) readings. How many readings it has is not how important it is.

        \(sections.joined(separator: "\n\n"))

        SMART GOALS
        Advice may name one of these when it makes the next step clearer. A goal is not a finding.
        \(goalsText(goals))
        """
        return CoachInsightPacket(text: body, metricCount: sections.count)
    }

    static func waitingCard(dateKey: String, kind: CoachCheckInKind, now: Date) -> CoachCheckIn {
        CoachCheckIn(
            kind: kind,
            dateKey: dateKey,
            healthLine: needsDataSentence,
            isFallback: true,
            generatedAt: now,
            waitingForHealthData: true
        )
    }

    /// Three panels in color order. A repeated topic, or a topic the record
    /// does not contain, is left blank.
    static func panels(
        greenTopic: String,
        greenFinding: String,
        greenAdvice: String,
        yellowTopic: String,
        yellowFinding: String,
        yellowAdvice: String,
        redTopic: String,
        redFinding: String,
        redAdvice: String,
        recordText: String
    ) -> [CoachInsightPanel] {
        let drafts = [
            draft(.green, greenTopic, greenFinding, greenAdvice),
            draft(.yellow, yellowTopic, yellowFinding, yellowAdvice),
            draft(.red, redTopic, redFinding, redAdvice)
        ]
        let record = recordText.lowercased()
        var seen = Set<String>()
        return drafts.map { panel in
            let key = panel.topic.lowercased()
            guard !panel.isBlank, key.count >= 3, record.contains(key), seen.insert(key).inserted else {
                return CoachInsightPanel(tone: panel.tone)
            }
            return panel
        }
    }

    private static func draft(
        _ tone: CoachInsightTone,
        _ topic: String,
        _ finding: String,
        _ advice: String
    ) -> CoachInsightPanel {
        CoachInsightPanel(
            tone: tone,
            topic: topic.trimmingCharacters(in: .whitespacesAndNewlines),
            finding: CoachReplyPolish.polish(finding.trimmingCharacters(in: .whitespacesAndNewlines)),
            advice: strippedAdvice(advice, tone: tone)
        )
    }

    private static func strippedAdvice(_ raw: String, tone: CoachInsightTone) -> String {
        var text = CoachReplyPolish.polish(raw.trimmingCharacters(in: .whitespacesAndNewlines))
        if text.hasPrefix(tone.actionLead) {
            text = String(text.dropFirst(tone.actionLead.count))
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return text
    }

    // MARK: - Daily records

    private static func nutritionSection(
        records: [DailyRecord],
        settings: UserSettings,
        todayKey: String,
        endKey: String
    ) -> String? {
        if settings.nutritionMode == .foodGroups {
            return dailySection(
                name: "Food groups",
                points: records.compactMap { record in
                    guard record.date < todayKey, record.foodGroups.isLogged else { return nil }
                    let servings = record.foodGroups.vegetables
                        + record.foodGroups.fruit
                        + record.foodGroups.wholeGrains
                        + record.foodGroups.legumesNuts
                        + record.foodGroups.fish
                    return (record.date, Double(servings))
                },
                endKey: endKey,
                line: { average in "average \(whole(average)) servings of vegetables, fruit, grains, legumes, and fish" },
                compared: { difference in
                    compared(difference, threshold: 1) { value in "\(whole(value)) servings" }
                }
            )
        }
        return dailySection(
            name: "Fiber",
            points: records.compactMap { record in
                guard record.date < todayKey, record.fiberGrams > 0 else { return nil }
                return (record.date, record.fiberGrams)
            },
            endKey: endKey,
            line: { average in "average \(whole(average)) g" },
            compared: { difference in
                compared(difference, threshold: 2) { value in "\(whole(value)) g" }
            }
        )
    }

    private static func movementSection(
        records: [DailyRecord],
        settings: UserSettings,
        todayKey: String,
        endKey: String
    ) -> String? {
        if settings.movementGoal.countsSteps {
            return dailySection(
                name: "Steps",
                points: records.compactMap { record in
                    guard record.date < todayKey, record.stepCount > 0 else { return nil }
                    return (record.date, record.stepCount)
                },
                endKey: endKey,
                line: { average in "average \(whole(average)) steps" },
                compared: { difference in
                    compared(difference, threshold: 500) { value in "\(whole(value)) steps" }
                }
            )
        }
        return dailySection(
            name: "Exercise minutes",
            points: records.compactMap { record in
                guard record.date < todayKey, record.exerciseMinutes > 0 else { return nil }
                return (record.date, record.exerciseMinutes)
            },
            endKey: endKey,
            line: { average in "average \(whole(average)) min" },
            compared: { difference in
                compared(difference, threshold: 5) { value in "\(whole(value)) min" }
            }
        )
    }

    private static func dailySection(
        name: String,
        points: [(String, Double)],
        endKey: String,
        line: (Double) -> String,
        compared: (Double) -> String
    ) -> String? {
        let stats = windowStats(points: points, endKey: endKey)
        guard stats.contains(where: { $0.count >= minimumPoints }) else { return nil }
        return section(name: name, stats: stats, describe: line, compared: compared)
    }

    // MARK: - Weight

    private static func weightSection(_ trend: BodyTrend?) -> String? {
        guard let trend, trend.readingCount >= minimumPoints else { return nil }
        var lines = ["Weight", "- \(trend.readingCount) readings."]
        if let smoothed = trend.smoothedKilograms {
            lines.append("- Seven-day average \(trend.unit.text(fromKilograms: smoothed)).")
        }
        if let change = trend.changeOverFourWeeks, let direction = trend.direction4w {
            lines.append("- \(weightChange(change, direction: direction, unit: trend.unit, period: "four weeks"))")
        }
        if let change = trend.changeOverTwelveWeeks, let direction = trend.direction12w {
            lines.append("- \(weightChange(change, direction: direction, unit: trend.unit, period: "twelve weeks"))")
        }
        if let bmi = trend.bmi {
            lines.append("- BMI \(bmi).")
        }
        return lines.joined(separator: "\n")
    }

    private static func weightChange(
        _ change: Double,
        direction: BodyTrend.Direction,
        unit: BodyMassUnit,
        period: String
    ) -> String {
        switch direction {
        case .steady:
            return "Steady over the last \(period) (\(unit.noiseBandDescription))."
        case .down:
            return "Down \(unit.text(fromKilograms: abs(change))) over the last \(period)."
        case .up:
            return "Up \(unit.text(fromKilograms: abs(change))) over the last \(period)."
        }
    }

    // MARK: - Apple Health measures

    private static func measureSection(_ facts: CoachHealthMeasureFacts, endKey: String) -> String? {
        switch facts.measure {
        case .bloodPressure:
            return pressureSection(facts, endKey: endKey)
        case .running:
            return runningSection(facts, endKey: endKey)
        case .heartRate, .restingHeartRate, .walkingHeartRate, .respiratoryRate, .bloodOxygen, .wristTemperature, .cardioFitness:
            return averageSection(facts, endKey: endKey)
        case .standMinutes, .daylight, .distance:
            return totalSection(facts, endKey: endKey)
        }
    }

    private static func averageSection(_ facts: CoachHealthMeasureFacts, endKey: String) -> String? {
        let points = facts.days.compactMap { day -> (String, Double)? in
            guard let average = day.average else { return nil }
            return (day.dateKey, average)
        }
        let stats = windowStats(points: points, endKey: endKey)
        guard stats.contains(where: { $0.count >= minimumPoints }) else { return nil }
        let style = averageStyle(facts)
        return section(name: facts.measure.title, stats: stats, describe: { value in
            "average \(style.text(value, facts))"
        }, compared: { difference in
            compared(difference, threshold: style.threshold) { value in
                style.text(value, facts)
            }
        })
    }

    private static func totalSection(_ facts: CoachHealthMeasureFacts, endKey: String) -> String? {
        let points = facts.days.compactMap { day -> (String, Double)? in
            guard let total = day.total, total > 0 else { return nil }
            return (day.dateKey, total)
        }
        let stats = windowStats(points: points, endKey: endKey)
        guard stats.contains(where: { $0.count >= minimumPoints }) else { return nil }
        return section(name: facts.measure.title, stats: stats, describe: { value in
            "average \(quantityText(facts.measure, value: value, facts: facts)) a day"
        }, compared: { difference in
            compared(difference, threshold: totalThreshold(facts.measure)) { value in
                quantityText(facts.measure, value: value, facts: facts)
            }
        })
    }

    private static func pressureSection(_ facts: CoachHealthMeasureFacts, endKey: String) -> String? {
        let readings = facts.days.flatMap { day in
            day.readings.map { (day.dateKey, $0.systolic, $0.diastolic) }
        }
        let stats = pressureWindows(readings: readings, endKey: endKey)
        guard stats.contains(where: { $0.count >= minimumPoints }) else { return nil }
        var lines = ["Blood pressure"]
        for stat in stats where stat.count > 0 {
            if stat.count < minimumPoints {
                lines.append("- Last \(stat.days) finished days: \(stat.count) \(stat.count == 1 ? "reading" : "readings"), too few to judge.")
            } else if let systolic = stat.systolic, let diastolic = stat.diastolic {
                lines.append("- Last \(stat.days) finished days: average \(whole(systolic))/\(whole(diastolic)) mmHg across \(stat.count) readings.")
            }
        }
        if let direction = pressureDirection(stats) {
            lines.append("- \(direction)")
        }
        return lines.joined(separator: "\n")
    }

    private static func runningSection(_ facts: CoachHealthMeasureFacts, endKey: String) -> String? {
        guard runningCount(facts, endKey: endKey) >= minimumPoints else { return nil }
        var lines = ["Running"]
        for days in [7, 30, 90] {
            let allowed = Set(keys(ending: endKey, days: days))
            let runs = facts.runs.filter { allowed.contains($0.dateKey) }
            guard !runs.isEmpty else { continue }
            let minutes = whole(runs.map(\.durationMinutes).reduce(0, +))
            if runs.count < minimumPoints {
                lines.append("- Last \(days) finished days: \(runs.count) \(runs.count == 1 ? "run" : "runs"), too few to judge.")
            } else {
                lines.append("- Last \(days) finished days: \(runs.count) runs, \(minutes) min total.")
            }
        }
        return lines.joined(separator: "\n")
    }

    private static func runningCount(_ facts: CoachHealthMeasureFacts, endKey: String) -> Int {
        let allowed = Set(keys(ending: endKey, days: 90))
        return facts.runs.filter { allowed.contains($0.dateKey) }.count
    }

    private static func workoutSections(
        _ workouts: [CoachWorkoutSummary],
        endKey: String,
        skipRunning: Bool
    ) -> [String] {
        let grouped = Dictionary(grouping: workouts, by: \.activity)
        return grouped.keys.sorted().compactMap { activity in
            if skipRunning && activity == "Running" { return nil }
            let rows = grouped[activity] ?? []
            let stats = windowStats(
                points: rows.map { ($0.dateKey, $0.durationMinutes) },
                endKey: endKey
            )
            guard stats.contains(where: { $0.count >= minimumPoints }) else { return nil }
            var lines = ["Workouts, \(activity)"]
            for stat in stats where stat.count > 0 {
                if stat.count < minimumPoints {
                    lines.append("- Last \(stat.days) finished days: \(stat.count) \(stat.count == 1 ? "session" : "sessions"), too few to judge.")
                } else {
                    let minutes = rows.filter { Set(keys(ending: endKey, days: stat.days)).contains($0.dateKey) }
                        .map(\.durationMinutes)
                        .reduce(0, +)
                    lines.append("- Last \(stat.days) finished days: \(stat.count) sessions, \(whole(minutes)) min total.")
                }
            }
            return lines.joined(separator: "\n")
        }
    }

    // MARK: - Windows

    private struct WindowStat {
        var days: Int
        var count: Int
        var average: Double?
    }

    private struct PressureStat {
        var days: Int
        var count: Int
        var systolic: Double?
        var diastolic: Double?
    }

    private static func windowStats(points: [(String, Double)], endKey: String) -> [WindowStat] {
        [7, 30, 90].map { days in
            let allowed = Set(keys(ending: endKey, days: days))
            let values = points.filter { allowed.contains($0.0) }.map(\.1)
            let average = values.isEmpty ? nil : values.reduce(0, +) / Double(values.count)
            return WindowStat(days: days, count: values.count, average: average)
        }
    }

    private static func pressureWindows(
        readings: [(String, Double, Double)],
        endKey: String
    ) -> [PressureStat] {
        [7, 30, 90].map { days in
            let allowed = Set(keys(ending: endKey, days: days))
            let rows = readings.filter { allowed.contains($0.0) }
            guard !rows.isEmpty else {
                return PressureStat(days: days, count: 0, systolic: nil, diastolic: nil)
            }
            let systolic = rows.map(\.1).reduce(0, +) / Double(rows.count)
            let diastolic = rows.map(\.2).reduce(0, +) / Double(rows.count)
            return PressureStat(days: days, count: rows.count, systolic: systolic, diastolic: diastolic)
        }
    }

    private static func section(
        name: String,
        stats: [WindowStat],
        describe: (Double) -> String,
        compared: (Double) -> String
    ) -> String {
        var lines = [name]
        for stat in stats where stat.count > 0 {
            if stat.count < minimumPoints {
                lines.append("- Last \(stat.days) finished days: \(stat.count) \(stat.count == 1 ? "day" : "days"), too few to judge.")
            } else if let average = stat.average {
                lines.append("- Last \(stat.days) finished days: \(describe(average)) across \(stat.count) days.")
            }
        }
        if let direction = directionLine(stats: stats, compared: compared) {
            lines.append("- \(direction)")
        }
        return lines.joined(separator: "\n")
    }

    private static func directionLine(stats: [WindowStat], compared: (Double) -> String) -> String? {
        let usable = stats.filter { $0.count >= minimumPoints && $0.average != nil }
        guard usable.count >= 2,
              let recent = usable.first,
              let prior = usable.dropFirst().first,
              let recentAverage = recent.average,
              let priorAverage = prior.average else { return nil }
        return "Recent direction: the \(recent.days)-day average is \(compared(recentAverage - priorAverage)) the \(prior.days)-day average."
    }

    private static func pressureDirection(_ stats: [PressureStat]) -> String? {
        let usable = stats.filter { $0.count >= minimumPoints && $0.systolic != nil }
        guard usable.count >= 2,
              let recent = usable.first,
              let prior = usable.dropFirst().first,
              let recentSystolic = recent.systolic,
              let priorSystolic = prior.systolic else { return nil }
        let phrase = compared(recentSystolic - priorSystolic, threshold: 3) { value in
            "\(whole(value)) mmHg"
        }
        return "Recent direction: the \(recent.days)-day systolic average is \(phrase) the \(prior.days)-day average."
    }

    private static func keys(ending endKey: String, days: Int) -> [String] {
        (0..<days).compactMap { DateHelpers.addDays(to: endKey, days: -$0) }
    }

    private static func compared(
        _ difference: Double,
        threshold: Double,
        magnitude: (Double) -> String
    ) -> String {
        if abs(difference) < threshold { return "in line with" }
        let word = difference > 0 ? "above" : "below"
        return "\(magnitude(abs(difference))) \(word)"
    }

    private static func whole(_ value: Double) -> String {
        let rounded = Int(value.rounded())
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: rounded)) ?? String(rounded)
    }

    // MARK: - Measure words

    private struct AverageStyle {
        var threshold: Double
        var text: (Double, CoachHealthMeasureFacts) -> String
    }

    private static func averageStyle(_ facts: CoachHealthMeasureFacts) -> AverageStyle {
        switch facts.measure {
        case .heartRate, .restingHeartRate, .walkingHeartRate:
            return AverageStyle(threshold: 2) { value, _ in "\(whole(value)) bpm" }
        case .respiratoryRate:
            return AverageStyle(threshold: 1) { value, _ in String(format: "%.1f breaths/min", value) }
        case .bloodOxygen:
            return AverageStyle(threshold: 1) { value, _ in "\(whole(value))%" }
        case .wristTemperature:
            return AverageStyle(threshold: 0.1) { value, facts in
                temperature(value, fahrenheit: facts.temperatureUsesFahrenheit)
            }
        case .cardioFitness:
            return AverageStyle(threshold: 1) { value, _ in String(format: "%.1f mL/kg/min", value) }
        default:
            return AverageStyle(threshold: 1) { value, _ in whole(value) }
        }
    }

    private static func totalThreshold(_ measure: CoachHealthMeasure) -> Double {
        switch measure {
        case .distance: return 500
        case .standMinutes, .daylight: return 5
        default: return 1
        }
    }

    private static func quantityText(
        _ measure: CoachHealthMeasure,
        value: Double,
        facts: CoachHealthMeasureFacts
    ) -> String {
        switch measure {
        case .distance:
            return distance(value, metric: facts.distanceUsesMetric)
        case .standMinutes:
            return "\(whole(value)) min"
        case .daylight:
            return CompletedTrendBuilder.formatSleep(value / 60)
        default:
            return whole(value)
        }
    }

    private static func distance(_ meters: Double, metric: Bool) -> String {
        if metric {
            if meters >= 1000 { return String(format: "%.1f km", meters / 1000) }
            return "\(whole(meters)) m"
        }
        return String(format: "%.1f mi", meters / 1609.344)
    }

    private static func temperature(_ celsius: Double, fahrenheit: Bool) -> String {
        if fahrenheit {
            return String(format: "%.1f °F", celsius * 9 / 5 + 32)
        }
        return String(format: "%.1f °C", celsius)
    }

    private static func goalsText(_ goals: [SMARTGoal]) -> String {
        let active = goals.filter { $0.status == .active && !$0.isComplete && !$0.isExpired }
        guard !active.isEmpty else { return "No active SMART goals." }
        return active.map { goal in
            let title = goal.specificText.trimmingCharacters(in: .whitespacesAndNewlines)
            return "- \(title): \(goal.filledCount) of \(goal.targetCount)."
        }.joined(separator: "\n")
    }
}
