import Foundation

/// Finer than `DayPhase`, so the Home coach card does not suggest lunch at 6pm.
enum CoachTimeOfDay: String, Equatable, Sendable {
    case morning
    case midday
    case afternoon
    case evening
    case night

    static func current(from date: Date = Date(), calendar: Calendar = .current) -> CoachTimeOfDay {
        let hour = calendar.component(.hour, from: date)
        switch hour {
        case 5..<11: return .morning
        case 11..<14: return .midday
        case 14..<17: return .afternoon
        case 17..<20:
            let minute = calendar.component(.minute, from: date)
            if hour == 19 && minute >= 30 { return .night }
            return .evening
        default:
            return .night
        }
    }

    /// Model-facing rules. Prefer the soonest window that has not passed.
    var promptRules: String {
        switch self {
        case .morning:
            return """
            It is morning. Prefer lunch or a late-morning walk. You may mention later today \
            (afternoon, dinner, tonight) as a plan, but lead with the next window. Do not write \
            as if it is already evening.
            """
        case .midday:
            return """
            It is midday. Lunch is the current window. Do not suggest breakfast. Afternoon, \
            dinner, and tonight are still ahead.
            """
        case .afternoon:
            return """
            It is afternoon. Lunch has passed — do not suggest after lunch, a midday meal, \
            or this morning. Dinner and tonight are still ahead.
            """
        case .evening:
            return """
            It is evening (about 5pm or later). Lunch and this afternoon have passed. Do not \
            suggest after lunch, a midday walk, or anything that needed the afternoon. Invite \
            dinner, tonight, or tomorrow morning only.
            """
        case .night:
            return """
            It is night. Do not suggest lunch, this afternoon, after work, or a daytime walk. \
            Invite a wind-down for tonight or a small plan for tomorrow morning.
            """
        }
    }
}

enum CoachClock {
    static func hourMinute(
        from date: Date = Date(),
        calendar: Calendar = .current
    ) -> (hour: Int, minute: Int) {
        (
            calendar.component(.hour, from: date),
            calendar.component(.minute, from: date)
        )
    }

    static func promptLabel(
        from date: Date = Date(),
        calendar: Calendar = .current
    ) -> String {
        let parts = hourMinute(from: date, calendar: calendar)
        let timeOfDay = CoachTimeOfDay.current(from: date, calendar: calendar)
        return "hour \(parts.hour), minute \(String(format: "%02d", parts.minute)) (\(timeOfDay.rawValue))"
    }
}

extension String {
    /// Keeps whole sentences under a character budget. Never appends an ellipsis.
    func endingOnSentence(maxCharacters: Int) -> String {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > maxCharacters else { return trimmed }
        let window = String(trimmed.prefix(maxCharacters))
        let marks: [Character] = [".", "!", "?"]
        if let index = window.lastIndex(where: { marks.contains($0) }) {
            return String(window[...index]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return trimmed
    }
}
