import Foundation

enum CoachFocusFeature: String, Codable, Sendable {
    case today
    case sleep
    case fiber
    case exercise
    case hrv
    case history
    case sleepDiagnostic
    case goal
}

/// Compact, typed coaching context built from app state — never from the model.
struct CoachFocusContext: Identifiable, Equatable, Sendable {
    var id: UUID
    var feature: CoachFocusFeature
    var metricName: String?
    var unit: String?
    var startDateKey: String?
    var endDateKey: String?
    var goalId: UUID?
    var valueSummary: String
    var baselineComparison: String
    var freshness: String
    var missingData: String

    init(
        id: UUID = UUID(),
        feature: CoachFocusFeature,
        metricName: String? = nil,
        unit: String? = nil,
        startDateKey: String? = nil,
        endDateKey: String? = nil,
        goalId: UUID? = nil,
        valueSummary: String = "",
        baselineComparison: String = "",
        freshness: String = "",
        missingData: String = ""
    ) {
        self.id = id
        self.feature = feature
        self.metricName = metricName
        self.unit = unit
        self.startDateKey = startDateKey
        self.endDateKey = endDateKey
        self.goalId = goalId
        self.valueSummary = valueSummary
        self.baselineComparison = baselineComparison
        self.freshness = freshness
        self.missingData = missingData
    }

    var isHistorical: Bool {
        switch feature {
        case .history, .sleepDiagnostic:
            return true
        case .hrv, .sleep, .fiber, .exercise:
            if let startDateKey, startDateKey != DateHelpers.localDateKey() { return true }
            if let endDateKey, endDateKey != DateHelpers.localDateKey() { return true }
            return false
        case .today, .goal:
            return false
        }
    }

    var title: String {
        switch feature {
        case .today: return "Today"
        case .sleep: return "Sleep"
        case .fiber: return "Fiber"
        case .exercise: return "Exercise"
        case .hrv: return "Heart rate variability"
        case .history: return "Selected history"
        case .sleepDiagnostic: return "Sleep records"
        case .goal: return "SMART goal"
        }
    }

    var promptBlock: String {
        var lines = [
            "SELECTED COACHING CONTEXT (built by the app; do not replace it with today's data unless the user asks about today):",
            "Screen: \(title)."
        ]
        if let metricName {
            lines.append("Metric: \(metricName)\(unit.map { " (\($0))" } ?? "").")
        }
        if let startDateKey, let endDateKey, startDateKey != endDateKey {
            lines.append("Selected period: \(DateHelpers.formatDisplayDate(startDateKey)) through \(DateHelpers.formatDisplayDate(endDateKey)).")
        } else if let startDateKey {
            lines.append("Selected date: \(DateHelpers.formatDisplayDate(startDateKey)).")
        }
        if !valueSummary.isEmpty { lines.append(valueSummary) }
        if !baselineComparison.isEmpty { lines.append(baselineComparison) }
        if !freshness.isEmpty { lines.append(freshness) }
        if !missingData.isEmpty { lines.append(missingData) }
        if isHistorical {
            lines.append("This is a historical selection. Do not silently switch to today.")
        }
        lines.append("Missing Health data is unlogged, not zero activity and not invented behavior.")
        return lines.joined(separator: "\n")
    }

    /// What they tapped, once, at the start of a chat. The numbers they were
    /// looking at, without instructions about how to answer.
    var openingFact: String {
        var lines = ["Opened from \(title)."]
        if let metricName {
            lines.append("Metric: \(metricName)\(unit.map { " (\($0))" } ?? "").")
        }
        if let startDateKey, let endDateKey, startDateKey != endDateKey {
            lines.append("Selected period: \(DateHelpers.formatDisplayDate(startDateKey)) through \(DateHelpers.formatDisplayDate(endDateKey)).")
        } else if let startDateKey {
            lines.append("Selected date: \(DateHelpers.formatDisplayDate(startDateKey)).")
        }
        if !valueSummary.isEmpty { lines.append(valueSummary) }
        if !freshness.isEmpty, !freshness.contains("Do not") {
            lines.append(freshness)
        }
        return lines.joined(separator: "\n")
    }
}

enum CoachFocusContextBuilder {
    static func metric(
        _ feature: CoachFocusFeature,
        record: DailyRecord,
        nowKey: String = DateHelpers.localDateKey()
    ) -> CoachFocusContext {
        let status: CoachMetricStatus
        switch feature {
        case .sleep:
            status = CoachSnapshotBuilder.status(
                name: "Sleep", value: record.sleepHours, goal: record.sleepGoal.rawValue,
                unit: "h", decimals: 1, points: record.sleepScore, maxPoints: 4
            )
        case .fiber:
            status = CoachSnapshotBuilder.status(
                name: "Fiber", value: record.fiberGrams, goal: Double(record.fiberGoal.rawValue),
                unit: "g", decimals: 1, points: record.fiberScore, maxPoints: 4
            )
        case .exercise:
            status = CoachSnapshotBuilder.status(
                name: "Exercise", value: record.exerciseMinutes, goal: Double(record.exerciseGoalMinutes),
                unit: "min", decimals: 0, points: record.exerciseScore, maxPoints: 2
            )
        default:
            status = CoachSnapshotBuilder.status(
                name: "Score", value: record.totalScore, goal: 10,
                unit: "pts", decimals: 1, points: record.totalScore, maxPoints: 10
            )
        }
        let missing = status.level == .missing
            ? "\(status.name) is unlogged for \(DateHelpers.formatDisplayDate(record.date)) — not zero behavior."
            : ""
        return CoachFocusContext(
            feature: feature,
            metricName: status.name,
            unit: status.unit,
            startDateKey: record.date,
            endDateKey: record.date,
            valueSummary: status.sentence,
            freshness: record.date == nowKey ? "This is today's saved record." : "This is a historical day, not today (\(DateHelpers.formatDisplayDate(nowKey))).",
            missingData: missing
        )
    }

    static func history(stats: RollingStats, days: Int, windowKeys: [String]) -> CoachFocusContext {
        let start = windowKeys.first ?? ""
        let end = windowKeys.last ?? ""
        let missingDays = max(stats.daysInWindow - stats.daysWithData, 0)
        let missing = missingDays > 0
            ? "\(missingDays) day(s) in this window have no saved record. That is missing data, not zero sleep, fiber, or exercise."
            : ""
        return CoachFocusContext(
            feature: .history,
            metricName: "Rolling score",
            unit: "points",
            startDateKey: start,
            endDateKey: end,
            valueSummary: String(
                format: "Average score %.1f of 10 across %d of %d days. Sleep %.1f h, fiber %.0f g, exercise %.0f min.",
                stats.avgTotalScore,
                stats.daysWithData,
                stats.daysInWindow,
                stats.avgSleepHours,
                stats.avgFiberGrams,
                stats.avgExerciseMinutes
            ),
            baselineComparison: "Comparisons use this selected \(days)-day window only.",
            freshness: "Window ends on \(end.isEmpty ? "the latest saved day" : DateHelpers.formatDisplayDate(end)).",
            missingData: missing
        )
    }

    static func day(_ record: DailyRecord?, dateKey: String, todayKey: String = DateHelpers.localDateKey()) -> CoachFocusContext {
        guard let record else {
            return CoachFocusContext(
                feature: .history,
                startDateKey: dateKey,
                endDateKey: dateKey,
                valueSummary: "No saved record for \(DateHelpers.formatDisplayDate(dateKey)).",
                freshness: "Today is \(DateHelpers.formatDisplayDate(todayKey)). Do not substitute it.",
                missingData: "No Health-backed record is stored for this date. That is missing data, not zero activity."
            )
        }
        let sleep = CoachSnapshotBuilder.status(
            name: "Sleep", value: record.sleepHours, goal: record.sleepGoal.rawValue,
            unit: "h", decimals: 1, points: record.sleepScore, maxPoints: 4
        )
        let fiber = CoachSnapshotBuilder.status(
            name: "Fiber", value: record.fiberGrams, goal: Double(record.fiberGoal.rawValue),
            unit: "g", decimals: 1, points: record.fiberScore, maxPoints: 4
        )
        let exercise = CoachSnapshotBuilder.status(
            name: "Exercise", value: record.exerciseMinutes, goal: Double(record.exerciseGoalMinutes),
            unit: "min", decimals: 0, points: record.exerciseScore, maxPoints: 2
        )
        let missingBits = [sleep, fiber, exercise].filter { $0.level == .missing }.map(\.name)
        return CoachFocusContext(
            feature: .history,
            metricName: "Daily record",
            startDateKey: dateKey,
            endDateKey: dateKey,
            valueSummary: "Score \(ScoreCalculator.formatDisplayScore(record.totalScore)) of 10. \(sleep.sentence) \(fiber.sentence) \(exercise.sentence)",
            freshness: dateKey == todayKey
                ? "This is today's saved record."
                : "This is \(DateHelpers.formatDisplayDate(dateKey)), not today (\(DateHelpers.formatDisplayDate(todayKey))).",
            missingData: missingBits.isEmpty
                ? ""
                : "\(missingBits.joined(separator: ", ")) unlogged on this day — not zero behavior."
        )
    }

    static func hrv(analysis: HRVAnalysis, startDateKey: String, endDateKey: String, todayKey: String) -> CoachFocusContext {
        CoachFocusContext(
            feature: .hrv,
            metricName: "Sleep HRV (SDNN)",
            unit: "ms",
            startDateKey: startDateKey,
            endDateKey: endDateKey,
            valueSummary: CoachHRVSummarizer.line(for: analysis),
            baselineComparison: "HRV uses this person's SDNN sleep values. Do not use rMSSD terminology or treat this as diagnosis, psychological stress, or definitive exercise readiness.",
            freshness: "Selected HRV window \(DateHelpers.formatDisplayDate(startDateKey)) through \(DateHelpers.formatDisplayDate(endDateKey)). Today is \(DateHelpers.formatDisplayDate(todayKey)).",
            missingData: analysis.acuteNightsWithData == 0
                ? "No SDNN nights are available in this window."
                : ""
        )
    }

    static func sleepDiagnostic(dateKey: String, attributedHours: Double, sampleCount: Int) -> CoachFocusContext {
        let missing = sampleCount == 0
            ? "No sleep samples were returned for this wake day. That is missing Health data, not a night of zero sleep."
            : ""
        return CoachFocusContext(
            feature: .sleepDiagnostic,
            metricName: "Sleep",
            unit: "h",
            startDateKey: dateKey,
            endDateKey: dateKey,
            valueSummary: String(format: "Attributed sleep for %@: %.1f h from %d Health sample(s).", DateHelpers.formatDisplayDate(dateKey), attributedHours, sampleCount),
            baselineComparison: "These are HealthKit samples attributed to this wake day.",
            freshness: "Diagnostic snapshot for \(DateHelpers.formatDisplayDate(dateKey)).",
            missingData: missing
        )
    }
}
