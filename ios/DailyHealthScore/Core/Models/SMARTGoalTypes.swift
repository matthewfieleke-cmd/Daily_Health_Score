import Foundation

// MARK: - Categories & themes

enum SMARTGoalCategory: String, CaseIterable, Identifiable, Codable {
    case sleep
    case fiber
    case exercise
    case relationshipBuilding
    case stressManagement

    var id: String { rawValue }

    var label: String {
        switch self {
        case .sleep: return "Sleep"
        case .fiber: return "Fiber"
        case .exercise: return "Exercise"
        case .relationshipBuilding: return "Relationship Building"
        case .stressManagement: return "Stress Management"
        }
    }

    var systemImage: String {
        switch self {
        case .sleep: return "moon.stars.fill"
        case .fiber: return "leaf.fill"
        case .exercise: return "figure.run"
        case .relationshipBuilding: return "heart.circle.fill"
        case .stressManagement: return "brain.head.profile"
        }
    }

    var isHealthPillar: Bool {
        switch self {
        case .sleep, .fiber, .exercise: return true
        case .relationshipBuilding, .stressManagement: return false
        }
    }
}

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
}

enum SMARTTimePreset: String, CaseIterable, Identifiable, Codable {
    case oneHour
    case oneDay
    case oneWeek

    var id: String { rawValue }

    var label: String {
        switch self {
        case .oneHour: return "1 hour"
        case .oneDay: return "1 day"
        case .oneWeek: return "1 week"
        }
    }
}

enum SMARTMeasurablePattern: String, Codable {
    /// N sessions (circles) within the goal window (e.g. 3× in a week).
    case sessionsInWindow
    /// One circle per day for 7 days from creation.
    case dailyForSevenDays
    /// Single completion with circle + confirm (Option A).
    case onceWithConfirm
}

enum SMARTGoalStatus: String, Codable {
    case active
    case ended
}

// MARK: - Wizard

enum SMARTWizardStep: Int, CaseIterable, Identifiable {
    case category = 0
    case specific
    case measurable
    case achievable
    case relevant
    case time
    case summary

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .category: return "Category"
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
        case .category: return "—"
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
    var category: SMARTGoalCategory
    var specificText: String
    var measurableDescription: String
    var measurablePattern: SMARTMeasurablePattern
    var targetCount: Int
    var achievableText: String
    var relevantTheme: SMARTRelevantTheme
    var timePreset: SMARTTimePreset
    var endDate: Date
    var createdAt: Date
    var generatedSummary: String
    var filledMask: Int
    var awaitingConfirm: Bool
    var status: SMARTGoalStatus
    var remindersEnabled: Bool
    var reminderHour: Int
    var reminderMinute: Int
    var reminderWeekdaysMask: Int

    var isYesNoStyle: Bool { measurablePattern == .onceWithConfirm }

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
