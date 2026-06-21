import Foundation

enum DateHelpers {
    /// Keep enough history to draw a complete 90-day HRV usual-range band.
    /// The earliest visible day needs its prior 28-day baseline plus the
    /// 7-day acute offset, so 90 visible days requires roughly 125 stored days.
    static let retentionDays = 125

    static func localDateKey(from date: Date = Date()) -> String {
        let calendar = Calendar.current
        let y = calendar.component(.year, from: date)
        let m = calendar.component(.month, from: date)
        let d = calendar.component(.day, from: date)
        return String(format: "%04d-%02d-%02d", y, m, d)
    }

    static func date(from key: String) -> Date? {
        let parts = key.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        return Calendar.current.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))
    }

    static func formatDisplayDate(_ key: String) -> String {
        guard let d = date(from: key) else { return key }
        return d.formatted(.dateTime.weekday(.wide).month(.wide).day().year())
    }

    static func addDays(to key: String, days: Int) -> String? {
        guard let start = date(from: key) else { return nil }
        guard let next = Calendar.current.date(byAdding: .day, value: days, to: start) else { return nil }
        return localDateKey(from: next)
    }

    static func rollingDateKeys(days: Int, endingOn anchor: Date = Date()) -> [String] {
        let calendar = Calendar.current
        let end = calendar.startOfDay(for: anchor)
        return (0 ..< days).reversed().compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: end) else { return nil }
            return localDateKey(from: day)
        }
    }
}
