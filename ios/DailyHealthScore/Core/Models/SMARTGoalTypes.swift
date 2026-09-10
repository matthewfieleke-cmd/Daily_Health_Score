import Foundation

// MARK: - Themes

enum SMARTRelevantTheme: String, CaseIterable, Identifiable, Codable {
    case marriage
    case parenting
    case health
    case relationships
    case finances
    case career
    case choresMisc

    var id: String { rawValue }

    var label: String {
        switch self {
        case .marriage: return "Marriage"
        case .parenting: return "Parenting"
        case .health: return "Health"
        case .relationships: return "Relationships"
        case .finances: return "Finances"
        case .career: return "Career"
        case .choresMisc: return "Chores/Misc"
        }
    }

    var systemImage: String {
        switch self {
        case .marriage: return "heart.circle.fill"
        case .parenting: return "figure.2.and.child.holdinghands"
        case .health: return "heart.fill"
        case .relationships: return "person.2.fill"
        case .finances: return "dollarsign.circle.fill"
        case .career: return "briefcase.fill"
        case .choresMisc: return "wrench.and.screwdriver.fill"
        }
    }
}

enum SMARTGoalStatus: String, Codable {
    case active
    case ended
    case paused
}

// MARK: - Wizard

enum SMARTWizardStep: Int, CaseIterable, Identifiable {
    case specific = 0
    case measurable
    case achievable
    case relevant
    case time
    case summary

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .specific: return "Specific"
        case .measurable: return "Measurable"
        case .achievable: return "Achievable"
        case .relevant: return "Relevant"
        case .time: return "Time-bound"
        case .summary: return "Summary"
        }
    }

    var letter: String {
        switch self {
        case .specific: return "S"
        case .measurable: return "M"
        case .achievable: return "A"
        case .relevant: return "R"
        case .time: return "T"
        case .summary: return "✓"
        }
    }
}

// MARK: - Domain model

/// Practical follow-through details that live on the saved goal, not only in chat.
struct SMARTGoalPlan: Equatable, Codable, Sendable {
    var personalReason: String = ""
    var cue: String = ""
    var expectedBarriers: String = ""
    var fallbackAction: String = ""
    var confidence: Int? = nil
    var followThroughEnabled: Bool = false
    var reflectionHour: Int = 20
    var reflectionMinute: Int = 0

    static let empty = SMARTGoalPlan()

    var hasContent: Bool {
        !personalReason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !cue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !expectedBarriers.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !fallbackAction.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || confidence != nil
            || followThroughEnabled
    }

    func promptLines() -> [String] {
        func line(_ label: String, _ value: String) -> String? {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : "\(label): \(trimmed)"
        }
        var lines = [
            line("Personal reason", personalReason),
            line("Intended cue", cue),
            line("Expected barriers", expectedBarriers),
            line("Smaller fallback (does not count as the accepted action)", fallbackAction)
        ].compactMap { $0 }
        if let confidence {
            lines.append("Reported confidence: \(confidence) of 10.")
        }
        if followThroughEnabled {
            lines.append(
                "Follow-through reminders opted in; reflection time \(String(format: "%02d:%02d", reflectionHour, reflectionMinute))."
            )
        }
        return lines
    }
}

struct SMARTGoal: Identifiable, Equatable, Codable {
    var id: UUID
    var specificText: String
    var targetCount: Int
    var relevantTheme: SMARTRelevantTheme
    var timeWindowDays: Int
    var endDate: Date
    var createdAt: Date
    var generatedSummary: String
    /// Derived display cache of net dated/undated check-ins. The activity ledger
    /// is the source of truth; this bitmask exists so Watch snapshots stay compact.
    var filledMask: Int
    var status: SMARTGoalStatus
    var remindersEnabled: Bool
    var reminderHour: Int
    var reminderMinute: Int
    var reminderWeekdaysMask: Int
    var plan: SMARTGoalPlan = .empty

    var filledCount: Int {
        (0 ..< targetCount).filter { isFilled($0) }.count
    }

    var isComplete: Bool { filledCount >= targetCount }

    var isPaused: Bool { status == .paused }

    var isExpired: Bool {
        Date() > endDate && !isComplete
    }

    var canLogCheckIn: Bool {
        status == .active && !isComplete && !isExpired
    }

    func isFilled(_ index: Int) -> Bool {
        guard index >= 0, index < targetCount else { return false }
        return (filledMask & (1 << index)) != 0
    }

    mutating func setFilled(_ index: Int, filled: Bool) {
        guard index >= 0, index < targetCount else { return }
        if filled {
            filledMask |= (1 << index)
        } else {
            filledMask &= ~(1 << index)
        }
    }

    /// Fills the lowest empty circle. Used by Watch check-ins so two in-flight
    /// taps cannot overwrite each other by sending a stale mask.
    @discardableResult
    mutating func fillNextEmpty() -> Bool {
        guard canLogCheckIn else { return false }
        for index in 0 ..< targetCount where !isFilled(index) {
            setFilled(index, filled: true)
            return true
        }
        return false
    }
}
