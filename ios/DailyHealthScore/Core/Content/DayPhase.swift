import Foundation

/// Time-of-day bucket for primary-focus suggestions on the Today screen.
enum DayPhase: String, Codable, Equatable {
    /// Before 7:30 PM local — stay on track today; anticipate evening slip risk.
    case day
    /// 7:30 PM and later — tonight / tomorrow planning is appropriate.
    case evening

    /// Local cutoff: 19:30 (7:30 PM).
    static func current(from date: Date = Date(), calendar: Calendar = .current) -> DayPhase {
        let hour = calendar.component(.hour, from: date)
        let minute = calendar.component(.minute, from: date)
        if hour > 19 || (hour == 19 && minute >= 30) {
            return .evening
        }
        return .day
    }
}
