import Foundation

// MARK: - Themes

enum SMARTRelevantTheme: String, CaseIterable, Identifiable, Codable {
    case health
    case marriage
    case parenting
    case relationships
    case stressManagement
    case growth

    var id: String { rawValue }

    var label: String {
        switch self {
        case .health: return "Health"
        case .marriage: return "Marriage"
        case .parenting: return "Parenting"
        case .relationships: return "Relationships"
        case .stressManagement: return "Stress management"
        case .growth: return "Growth"
        }
    }

    var systemImage: String {
        switch self {
        case .health: return "heart.fill"
        case .marriage: return "heart.circle.fill"
        case .parenting: return "figure.2.and.child.holdinghands"
        case .relationships: return "person.2.fill"
        case .stressManagement: return "brain.head.profile"
        case .growth: return "tree.fill"
        }
    }
}

enum SMARTGoalStatus: String, Codable {
    case active
    case ended
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

struct SMARTGoal: Identifiable, Equatable {
    var id: UUID
    var specificText: String
    var targetCount: Int
    var relevantTheme: SMARTRelevantTheme
    var timeWindowDays: Int
    var endDate: Date
    var createdAt: Date
    var generatedSummary: String
    var filledMask: Int
    var status: SMARTGoalStatus
    var remindersEnabled: Bool
    var reminderHour: Int
    var reminderMinute: Int
    var reminderWeekdaysMask: Int

    var filledCount: Int {
        (0 ..< targetCount).filter { isFilled($0) }.count
    }

    var isComplete: Bool { filledCount >= targetCount }

    var isExpired: Bool {
        Date() > endDate && !isComplete
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
}
