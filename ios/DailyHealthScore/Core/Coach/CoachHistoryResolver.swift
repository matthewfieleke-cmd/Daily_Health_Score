import Foundation

/// Resolves "yesterday" / "last Tuesday" style references to real records and
/// renders them with the same precomputed comparisons today's metrics get.
///
/// Date arithmetic and goal comparison stay in Swift; the model only reads
/// finished sentences.
enum CoachHistoryResolver {
    struct Reference: Equatable, Sendable {
        let dateKey: String
        /// How the user referred to it, e.g. "yesterday" or "last Tuesday".
        let phrase: String
    }

    private static let weekdayNames = [
        "sunday", "monday", "tuesday", "wednesday", "thursday", "friday", "saturday"
    ]

    /// Cues that make a bare weekday a question about the past rather than a plan.
    private static let pastCues = [
        "did", "was", "were", "how", "what", "score", "sleep", "slept", "fiber",
        "exercise", "workout", "hrv", "compare", "back on"
    ]

    static func resolve(
        message: String,
        todayKey: String,
        calendar: Calendar = .current
    ) -> [Reference] {
        let text = " " + message.lowercased() + " "
        guard let today = DateHelpers.date(from: todayKey) else { return [] }

        var references: [Reference] = []

        if text.contains(" yesterday") || text.contains(" last night") {
            if let key = DateHelpers.addDays(to: todayKey, days: -1) {
                let phrase = text.contains(" last night") ? "last night" : "yesterday"
                references.append(Reference(dateKey: key, phrase: phrase))
            }
        }

        if text.contains(" day before yesterday") {
            if let key = DateHelpers.addDays(to: todayKey, days: -2) {
                references.append(Reference(dateKey: key, phrase: "the day before yesterday"))
            }
        }

        let hasPastCue = pastCues.contains { text.contains(" \($0)") }
        for (index, name) in weekdayNames.enumerated() {
            guard text.contains(" \(name)") else { continue }
            let explicitlyPast = text.contains(" last \(name)")
            guard explicitlyPast || hasPastCue else { continue }
            guard let key = mostRecentPast(
                weekdayIndex: index + 1,
                before: today,
                calendar: calendar
            ) else { continue }
            let phrase = explicitlyPast ? "last \(name.capitalized)" : name.capitalized
            if !references.contains(where: { $0.dateKey == key }) {
                references.append(Reference(dateKey: key, phrase: phrase))
            }
        }

        return Array(references.prefix(3))
    }

    /// Most recent occurrence of a weekday strictly before today.
    private static func mostRecentPast(
        weekdayIndex: Int,
        before today: Date,
        calendar: Calendar
    ) -> String? {
        for offset in 1 ... 7 {
            guard let candidate = calendar.date(byAdding: .day, value: -offset, to: today) else { continue }
            if calendar.component(.weekday, from: candidate) == weekdayIndex {
                return DateHelpers.localDateKey(from: candidate)
            }
        }
        return nil
    }

    /// Prompt block of precomputed metric sentences for any referenced days.
    static func block(
        message: String,
        records: [DailyRecord],
        todayKey: String,
        characterBudget: Int,
        calendar: Calendar = .current
    ) -> String? {
        let references = resolve(message: message, todayKey: todayKey, calendar: calendar)
        guard !references.isEmpty else { return nil }

        var lines: [String] = []
        for reference in references {
            let display = DateHelpers.formatDisplayDate(reference.dateKey)
            guard let record = records.first(where: { $0.date == reference.dateKey }) else {
                lines.append("\(reference.phrase.capitalized) (\(display)): no record saved for that day.")
                continue
            }

            let sleep = CoachSnapshotBuilder.status(
                name: "Sleep",
                value: record.sleepHours,
                goal: record.sleepGoal.rawValue,
                unit: "h",
                decimals: 1,
                points: record.sleepScore,
                maxPoints: 4
            )
            let fiber = CoachSnapshotBuilder.status(
                name: "Fiber",
                value: record.fiberGrams,
                goal: Double(record.fiberGoal.rawValue),
                unit: "g",
                decimals: 1,
                points: record.fiberScore,
                maxPoints: 4
            )
            let exercise = CoachSnapshotBuilder.status(
                name: "Exercise",
                value: record.exerciseMinutes,
                goal: Double(record.exerciseGoalMinutes),
                unit: "min",
                decimals: 0,
                points: record.exerciseScore,
                maxPoints: 2
            )

            lines.append("\(reference.phrase.capitalized) (\(display)) — score \(ScoreCalculator.formatDisplayScore(record.totalScore)) of 10:")
            lines.append("- \(sleep.sentence)")
            lines.append("- \(fiber.sentence)")
            lines.append("- \(exercise.sentence)")
        }

        return lines.joined(separator: "\n").limitedToCoachBudget(characterBudget)
    }
}
