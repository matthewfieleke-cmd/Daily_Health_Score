import Foundation

/// Any past day or stretch of days the Coach asks for. The model names the
/// window it wants; the date arithmetic, the goal comparison, and the averages
/// happen here, so it reads finished numbers instead of computing them.
enum CoachDayRange {
    struct Window: Equatable, Sendable {
        let startKey: String
        let endKey: String
    }

    /// Longest stretch rendered day by day. Past this it becomes week averages,
    /// because a hundred day-lines is a worse answer than a shape.
    static let maxDetailDays = 31

    /// The window, clamped to what the app still stores and to today. Dates win
    /// when given; the offsets are there for when the model does not know the date.
    static func resolve(
        startDate: String? = nil,
        endDate: String? = nil,
        startDaysAgo: Int? = nil,
        endDaysAgo: Int? = nil,
        todayKey: String,
        retentionDays: Int = DateHelpers.retentionDays
    ) -> Window? {
        let earliest = DateHelpers.addDays(to: todayKey, days: -(max(retentionDays, 1) - 1)) ?? todayKey
        let start = key(fromDate: startDate, daysAgo: startDaysAgo, todayKey: todayKey)
        let end = key(fromDate: endDate, daysAgo: endDaysAgo, todayKey: todayKey)
        guard var first = start ?? end, var last = end ?? start else { return nil }
        if first > last { swap(&first, &last) }
        // A window entirely in the future, or entirely before what we kept.
        guard first <= todayKey, last >= earliest else { return nil }
        return Window(startKey: Swift.max(first, earliest), endKey: Swift.min(last, todayKey))
    }

    static func payload(records: [DailyRecord], window: Window, todayKey: String) -> String {
        let keys = dateKeys(in: window)
        let byDate = Dictionary(records.map { ($0.date, $0) }, uniquingKeysWith: { _, latest in latest })
        let found = keys.compactMap { byDate[$0] }
        let today = "Today is \(label(todayKey)), \(year(todayKey))."

        if keys.count == 1 {
            guard let record = found.first else {
                return "\(label(window.startKey)), \(year(window.startKey)): no record saved. Unlogged, not zero. \(today)"
            }
            return "\(dayLine(record)) \(today)"
        }

        var lines = ["\(monthDay(window.startKey)) to \(monthDay(window.endKey)), \(year(window.endKey)) — \(keys.count) days, \(found.count) with data."]
        if let averages = averageLine(found, label: "Average across days with data") {
            lines.append(averages)
        }
        if found.isEmpty {
            lines.append("No days in this window have a record. Unlogged, not zero.")
        } else if keys.count <= maxDetailDays {
            lines.append(contentsOf: found.map(dayLine))
            lines.append(contentsOf: missingNote(keys: keys, byDate: byDate))
        } else {
            lines.append(contentsOf: weekLines(keys: keys, byDate: byDate))
        }
        lines.append(today)
        return lines.joined(separator: "\n")
    }

    /// What to say when the arguments named no readable window.
    static func guidance(todayKey: String, retentionDays: Int = DateHelpers.retentionDays) -> String {
        let earliest = DateHelpers.addDays(to: todayKey, days: -(max(retentionDays, 1) - 1)) ?? todayKey
        return """
        No window to read. Today is \(label(todayKey)), \(year(todayKey)), and records go back to \
        \(label(earliest)), \(year(earliest)). Give startDate and endDate as yyyy-MM-dd inside that \
        window, or startDaysAgo and endDaysAgo counting back from today.
        """
    }

    // MARK: - Lines

    private static func dayLine(_ record: DailyRecord) -> String {
        var parts = [
            "\(label(record.date)): score \(ScoreCalculator.formatDisplayScore(record.totalScore)) of 10",
            "sleep \(number(record.sleepHours, decimals: 1)) h of \(number(record.sleepGoal.rawValue, decimals: 1))",
            "fiber \(number(record.fiberGrams, decimals: 1)) g of \(record.fiberGoal.rawValue)",
            "exercise \(number(record.exerciseMinutes, decimals: 0)) min of \(record.exerciseGoalMinutes)"
        ]
        if let hrv = record.sleepHrvSDNNMs {
            parts.append("sleep HRV \(number(hrv, decimals: 0)) ms")
        }
        return parts.joined(separator: "; ") + "."
    }

    private static func averageLine(_ records: [DailyRecord], label: String) -> String? {
        guard !records.isEmpty else { return nil }
        let count = Double(records.count)
        let score = records.map(\.totalScore).reduce(0, +) / count
        let sleep = records.map(\.sleepHours).reduce(0, +) / count
        let fiber = records.map(\.fiberGrams).reduce(0, +) / count
        let exercise = records.map(\.exerciseMinutes).reduce(0, +) / count
        return "\(label): score \(ScoreCalculator.formatDisplayScore(score)) of 10, sleep \(number(sleep, decimals: 1)) h, fiber \(number(fiber, decimals: 1)) g, exercise \(number(exercise, decimals: 0)) min."
    }

    private static func missingNote(keys: [String], byDate: [String: DailyRecord]) -> [String] {
        let missing = keys.filter { byDate[$0] == nil }
        guard !missing.isEmpty else { return [] }
        let named = missing.prefix(6).map(monthDay).joined(separator: ", ")
        let rest = missing.count > 6 ? " and \(missing.count - 6) more" : ""
        return ["No record for \(named)\(rest). Unlogged, not zero."]
    }

    private static func weekLines(keys: [String], byDate: [String: DailyRecord]) -> [String] {
        stride(from: 0, to: keys.count, by: 7).compactMap { offset in
            let chunk = Array(keys[offset ..< Swift.min(offset + 7, keys.count)])
            guard let first = chunk.first, let last = chunk.last else { return nil }
            let found = chunk.compactMap { byDate[$0] }
            let span = "\(monthDay(first)) to \(monthDay(last))"
            guard let averages = averageLine(found, label: "\(span), \(found.count) of \(chunk.count) days with data") else {
                return "\(span): no days with data."
            }
            return averages
        }
    }

    // MARK: - Keys and words

    private static func key(fromDate date: String?, daysAgo: Int?, todayKey: String) -> String? {
        if let date {
            let trimmed = date.trimmingCharacters(in: .whitespacesAndNewlines)
            if let parsed = DateHelpers.date(from: trimmed) {
                return DateHelpers.localDateKey(from: parsed)
            }
        }
        if let daysAgo, daysAgo >= 0, daysAgo <= 3_650 {
            return DateHelpers.addDays(to: todayKey, days: -daysAgo)
        }
        return nil
    }

    private static func dateKeys(in window: Window) -> [String] {
        var keys: [String] = []
        var cursor = window.startKey
        while cursor <= window.endKey, keys.count < DateHelpers.retentionDays {
            keys.append(cursor)
            guard let next = DateHelpers.addDays(to: cursor, days: 1) else { break }
            cursor = next
        }
        return keys
    }

    private static let weekdayNames = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
    private static let monthNames = [
        "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"
    ]

    /// "Mon Sep 1". Built from the key rather than a formatter so the words do
    /// not change with the device locale.
    static func label(_ key: String, calendar: Calendar = .current) -> String {
        guard let date = DateHelpers.date(from: key) else { return key }
        let weekday = calendar.component(.weekday, from: date)
        let name = weekdayNames[Swift.min(Swift.max(weekday - 1, 0), 6)]
        return "\(name) \(monthDay(key))"
    }

    static func monthDay(_ key: String) -> String {
        let parts = key.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3, (1 ... 12).contains(parts[1]) else { return key }
        return "\(monthNames[parts[1] - 1]) \(parts[2])"
    }

    static func year(_ key: String) -> String { String(key.prefix(4)) }

    private static func number(_ value: Double, decimals: Int) -> String {
        String(format: "%.\(decimals)f", value)
    }
}
