import Foundation

/// Sleep, fiber, or the movement goal the person selected.
enum TrendMetric: String, Codable, CaseIterable, Identifiable, Sendable {
    case sleep
    case fiber
    case movement

    var id: String { rawValue }

    static func parse(_ raw: String) -> TrendMetric? {
        switch raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        {
        case "sleep": return .sleep
        case "fiber", "fibre": return .fiber
        case "movement", "steps", "exercise", "exercise minutes": return .movement
        default: return nil
        }
    }
}

/// A chart the Coach asked the app to draw. The window stays the one that was shown.
struct TrendChartReference: Equatable, Codable, Identifiable, Sendable {
    var metric: TrendMetric
    var endDateKey: String
    var dayCount: Int
    /// Movement goal in effect when the chart was drawn. Empty for sleep and fiber.
    var movementGoalRaw: String = ""
    /// Nutrition mode when a fiber chart was drawn. Empty on older charts, which were grams.
    var nutritionModeRaw: String = ""

    var id: String { "\(metric.rawValue)|\(endDateKey)|\(dayCount)|\(movementGoalRaw)|\(nutritionModeRaw)" }
}

struct TrendBar: Equatable, Sendable, Identifiable {
    var dateKey: String
    var label: String
    var value: Double

    var id: String { dateKey }
}

struct CompletedWindowAverage: Equatable, Sendable {
    var requestedDays: Int
    var dayCount: Int
    var average: Double
    var isPartial: Bool
}

/// One metric over finished days. Today is never included.
struct CompletedTrend: Equatable, Sendable {
    var metric: TrendMetric
    var title: String
    var goal: Double
    var bars: [TrendBar]
    var average: Double
    var isPartial: Bool
    var endDateKey: String
    var thirty: CompletedWindowAverage?
    var ninety: CompletedWindowAverage?
    var rangeLabel: String
    var headline: String
    var goalText: String
    var thirtyText: String?
    var ninetyText: String?
    var caption: String
    var accessibilitySummary: String
    var coachSummary: String

    func reference(settings: UserSettings) -> TrendChartReference {
        TrendChartReference(
            metric: metric,
            endDateKey: endDateKey,
            dayCount: bars.count,
            movementGoalRaw: metric == .movement ? settings.movementGoal.rawValue : "",
            nutritionModeRaw: metric == .fiber ? settings.nutritionMode.rawValue : ""
        )
    }

    var blankDays: Int {
        bars.filter { $0.value <= 0 }.count
    }
}

enum CompletedTrendBuilder {
    static func build(
        metric: TrendMetric,
        records: [DailyRecord],
        settings: UserSettings,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> CompletedTrend? {
        guard let endKey = yesterdayKey(now: now, calendar: calendar) else { return nil }
        return build(
            metric: metric,
            records: records,
            settings: settings,
            endingOn: endKey,
            calendar: calendar
        )
    }

    static func build(
        reference: TrendChartReference,
        records: [DailyRecord],
        settings: UserSettings,
        calendar: Calendar = .current
    ) -> CompletedTrend? {
        var resolved = settings
        if reference.metric == .movement, let goal = MovementGoal(rawValue: reference.movementGoalRaw) {
            resolved.movementGoal = goal
        }
        if reference.metric == .fiber {
            // Older charts have no mode. Those were Apple Health grams.
            resolved.nutritionMode = NutritionMode(rawValue: reference.nutritionModeRaw) ?? .fiber
        }
        return build(
            metric: reference.metric,
            records: records,
            settings: resolved,
            endingOn: reference.endDateKey,
            dayCount: reference.dayCount,
            calendar: calendar
        )
    }

    static func build(
        metric: TrendMetric,
        records: [DailyRecord],
        settings: UserSettings,
        endingOn endKey: String,
        dayCount: Int = 7,
        calendar: Calendar = .current
    ) -> CompletedTrend? {
        let span = effectiveKeys(count: dayCount, endingOn: endKey, records: records, calendar: calendar)
        guard !span.keys.isEmpty else { return nil }
        let byDate = Dictionary(records.map { ($0.date, $0) }, uniquingKeysWith: { _, latest in latest })
        let bars = span.keys.map { key in
            TrendBar(
                dateKey: key,
                label: weekdayLetter(for: key, calendar: calendar),
                value: value(metric, record: byDate[key], settings: settings)
            )
        }
        let average = mean(bars.map(\.value))
        let thirty = windowAverage(requested: 30, endingOn: endKey, records: records, metric: metric, settings: settings, calendar: calendar)
        let ninety = windowAverage(requested: 90, endingOn: endKey, records: records, metric: metric, settings: settings, calendar: calendar)
        let title = Self.title(for: metric, settings: settings)
        let goal = Self.goal(for: metric, settings: settings)
        let range = rangeLabel(start: span.keys[0], end: span.keys[span.keys.count - 1])
        let headline = formatValue(average, metric: metric, settings: settings)
        let goalText = formatValue(goal, metric: metric, settings: settings)
        let blank = bars.filter { $0.value <= 0 }.count
        let caption = caption(range: range, dayCount: bars.count, blank: blank, isPartial: span.isPartial)
        let thirtyText = thirty.map { windowText($0, metric: metric, settings: settings) }
        let ninetyText = ninety.map { windowText($0, metric: metric, settings: settings) }
        let longer = [thirtyText, ninetyText].compactMap { $0 }.joined(separator: ". ")
        let summary = coachSummary(
            title: title,
            headline: headline,
            caption: caption,
            longer: longer,
            goal: goalText
        )
        return CompletedTrend(
            metric: metric,
            title: title,
            goal: goal,
            bars: bars,
            average: average,
            isPartial: span.isPartial,
            endDateKey: endKey,
            thirty: thirty,
            ninety: ninety,
            rangeLabel: range,
            headline: headline,
            goalText: goalText,
            thirtyText: thirtyText,
            ninetyText: ninetyText,
            caption: caption,
            accessibilitySummary: summary,
            coachSummary: summary
        )
    }

    /// Short facts for the Home card. Today is excluded. Missing logs are zero.
    static func promptFacts(
        records: [DailyRecord],
        settings: UserSettings,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> String {
        let lines = TrendMetric.allCases.compactMap { metric -> String? in
            build(metric: metric, records: records, settings: settings, now: now, calendar: calendar)?.coachSummary
        }
        guard !lines.isEmpty else {
            return "COMPLETED DAY FACTS: none yet. Today is still in progress and is not part of a finished-day average."
        }
        return "COMPLETED DAY FACTS (today is excluded; a day with nothing logged counts as zero):\n"
            + lines.map { "- \($0)" }.joined(separator: "\n")
    }

    /// Finished days for a rolling screen. Gaps inside the window are zero records.
    static func filledRecords(
        days: Int,
        records: [DailyRecord],
        settings: UserSettings,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> [DailyRecord] {
        guard let endKey = yesterdayKey(now: now, calendar: calendar) else { return [] }
        let span = effectiveKeys(count: days, endingOn: endKey, records: records, calendar: calendar)
        let byDate = Dictionary(records.map { ($0.date, $0) }, uniquingKeysWith: { _, latest in latest })
        return span.keys.map { key in
            byDate[key] ?? zeroRecord(date: key, settings: settings)
        }
    }

    static func zeroRecord(date: String, settings: UserSettings) -> DailyRecord {
        let metrics = DailyMetrics(sleepHours: 0, fiberGrams: 0, exerciseMinutes: 0, stepCount: 0)
        let computed = ScoreCalculator.calculate(metrics: metrics, settings: settings)
        return DailyRecord(
            date: date,
            sleepHours: 0,
            fiberGrams: 0,
            exerciseMinutes: 0,
            stepCount: 0,
            sleepGoal: settings.sleepGoal,
            fiberGoal: settings.fiberGoal,
            movementGoal: settings.movementGoal,
            sleepScore: computed.sleepScore,
            fiberScore: computed.fiberScore,
            exerciseScore: computed.exerciseScore,
            totalScore: computed.totalScore,
            sleepPercent: computed.sleepPercent,
            fiberPercent: computed.fiberPercent,
            exercisePercent: computed.exercisePercent,
            primaryFocus: ScoreCalculator.determinePrimaryFocus(computed),
            suggestion: "",
            createdAt: Date(timeIntervalSince1970: 0),
            updatedAt: Date(timeIntervalSince1970: 0)
        )
    }

    static func formatValue(_ value: Double, metric: TrendMetric, settings: UserSettings) -> String {
        switch metric {
        case .sleep:
            return formatSleep(value)
        case .fiber:
            if settings.nutritionMode == .foodGroups {
                return ScoreCalculator.formatDisplayScore(value)
            }
            return "\(ScoreCalculator.formatDisplayScore(value)) g"
        case .movement:
            if settings.movementGoal.countsSteps {
                return "\(MovementGoal.formatCount(value)) steps"
            }
            return "\(Int(value.rounded())) min"
        }
    }

    static func formatSleep(_ hours: Double) -> String {
        let totalMinutes = Int((hours * 60).rounded())
        let wholeHours = totalMinutes / 60
        let minutes = abs(totalMinutes % 60)
        if wholeHours <= 0 { return "\(minutes) min" }
        if minutes == 0 { return "\(wholeHours) hr" }
        return "\(wholeHours) hr \(minutes) min"
    }

    static func title(for metric: TrendMetric, settings: UserSettings) -> String {
        switch metric {
        case .sleep: return "Sleep"
        case .fiber: return settings.nutritionMode.cardTitle
        case .movement: return settings.movementGoal.metricName
        }
    }

    static func goal(for metric: TrendMetric, settings: UserSettings) -> Double {
        switch metric {
        case .sleep: return settings.sleepGoal.rawValue
        case .fiber: return settings.nutritionMode == .foodGroups ? 4 : UserSettings.fiberGoalGrams
        case .movement: return settings.movementGoal.goalValue
        }
    }

    // MARK: - Windows

    struct KeySpan: Equatable {
        var keys: [String]
        var isPartial: Bool
    }

    /// Calendar days ending on `endKey`. Days before the first saved record are
    /// not invented. Once a full window exists, a gap inside it stays in the list.
    static func effectiveKeys(
        count: Int,
        endingOn endKey: String,
        records: [DailyRecord],
        calendar: Calendar = .current
    ) -> KeySpan {
        guard count > 0 else { return KeySpan(keys: [], isPartial: false) }
        let window = keys(count: count, endingOn: endKey, calendar: calendar)
        let saved = records.map(\.date).filter { $0 <= endKey }
        guard let first = saved.min(), let start = window.first else {
            return KeySpan(keys: [], isPartial: false)
        }
        if first <= start {
            return KeySpan(keys: window, isPartial: false)
        }
        var partial: [String] = []
        var cursor = first
        while cursor <= endKey {
            partial.append(cursor)
            guard let next = DateHelpers.addDays(to: cursor, days: 1) else { break }
            cursor = next
        }
        return KeySpan(keys: partial, isPartial: true)
    }

    static func keys(count: Int, endingOn endKey: String, calendar: Calendar) -> [String] {
        guard let end = date(endKey, calendar: calendar) else { return [] }
        return (0 ..< count).reversed().compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: end) else { return nil }
            return key(day, calendar: calendar)
        }
    }

    static func yesterdayKey(now: Date, calendar: Calendar) -> String? {
        guard let yesterday = calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: now)) else {
            return nil
        }
        return key(yesterday, calendar: calendar)
    }

    // MARK: - Private

    private static func windowAverage(
        requested: Int,
        endingOn endKey: String,
        records: [DailyRecord],
        metric: TrendMetric,
        settings: UserSettings,
        calendar: Calendar
    ) -> CompletedWindowAverage? {
        let span = effectiveKeys(count: requested, endingOn: endKey, records: records, calendar: calendar)
        guard !span.keys.isEmpty else { return nil }
        let byDate = Dictionary(records.map { ($0.date, $0) }, uniquingKeysWith: { _, latest in latest })
        let values = span.keys.map { value(metric, record: byDate[$0], settings: settings) }
        return CompletedWindowAverage(
            requestedDays: requested,
            dayCount: span.keys.count,
            average: mean(values),
            isPartial: span.isPartial
        )
    }

    private static func value(_ metric: TrendMetric, record: DailyRecord?, settings: UserSettings) -> Double {
        guard let record else { return 0 }
        switch metric {
        case .sleep: return max(record.sleepHours, 0)
        case .fiber:
            if settings.nutritionMode == .foodGroups {
                return FoodGroupScore.points(record.foodGroups)
            }
            return max(record.fiberGrams, 0)
        case .movement:
            let raw = settings.movementGoal.countsSteps ? record.stepCount : record.exerciseMinutes
            return max(raw, 0)
        }
    }

    private static func mean(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        return values.reduce(0, +) / Double(values.count)
    }

    private static func caption(range: String, dayCount: Int, blank: Int, isPartial: Bool) -> String {
        var parts: [String] = []
        if isPartial {
            let noun = dayCount == 1 ? "day" : "days"
            parts.append("\(dayCount) completed \(noun) so far, \(range).")
        } else {
            parts.append("\(range). Today is still in progress and is not included.")
        }
        if blank > 0 {
            let noun = blank == 1 ? "day has" : "days have"
            parts.append("\(blank) of \(dayCount) \(noun) nothing logged. Those days count as zero.")
        }
        return parts.joined(separator: " ")
    }

    private static func windowText(
        _ window: CompletedWindowAverage,
        metric: TrendMetric,
        settings: UserSettings
    ) -> String {
        let value = formatValue(window.average, metric: metric, settings: settings)
        if window.isPartial {
            return "\(window.requestedDays)-day average is \(value) from \(window.dayCount) completed days so far"
        }
        return "\(window.requestedDays)-day average is \(value)"
    }

    private static func coachSummary(
        title: String,
        headline: String,
        caption: String,
        longer: String,
        goal: String
    ) -> String {
        var sentence = "\(title): 7-day picture averages \(headline). Goal \(goal). \(caption)"
        if !longer.isEmpty {
            sentence += " \(longer)."
        }
        return sentence
    }

    private static func rangeLabel(start: String, end: String) -> String {
        if start == end { return shortDate(start) }
        return "\(shortDate(start))–\(shortDate(end))"
    }

    private static func shortDate(_ key: String) -> String {
        guard let date = date(key, calendar: .current) else { return key }
        return date.formatted(.dateTime.month(.abbreviated).day())
    }

    static func weekdayLetter(for key: String, calendar: Calendar) -> String {
        guard let date = date(key, calendar: calendar) else { return "" }
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        let index = calendar.component(.weekday, from: date) - 1
        guard symbols.indices.contains(index) else { return "" }
        return String(symbols[index].prefix(1))
    }

    private static func date(_ key: String, calendar: Calendar) -> Date? {
        let parts = key.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        var components = DateComponents()
        components.year = parts[0]
        components.month = parts[1]
        components.day = parts[2]
        return calendar.date(from: components)
    }

    private static func key(_ date: Date, calendar: Calendar) -> String {
        let year = calendar.component(.year, from: date)
        let month = calendar.component(.month, from: date)
        let day = calendar.component(.day, from: date)
        return String(format: "%04d-%02d-%02d", year, month, day)
    }
}
