import Foundation

/// Structured daily card content shown on Today.
struct DailyCoachCardContent: Equatable, Codable, Sendable {
    var acknowledgment: String
    var whyItMatters: String
    var nextStep: String
}

/// Durable preferences/constraints that INFORM the coach; never override the charter.
struct CoachUserProfile: Equatable, Codable, Sendable {
    var preferredStyle: String = ""
    var constraints: String = ""
    var nutritionNotes: String = ""
    var movementNotes: String = ""
    var sleepNotes: String = ""
    var values: String = ""
    var whatHelps: String = ""
    var whatToAvoid: String = ""

    var isEmpty: Bool {
        [
            preferredStyle, constraints, nutritionNotes, movementNotes,
            sleepNotes, values, whatHelps, whatToAvoid
        ].allSatisfy { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    var promptBlock: String {
        if isEmpty { return "No durable profile notes yet." }
        func line(_ label: String, _ value: String) -> String? {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : "- \(label): \(trimmed)"
        }
        return [
            line("Preferred style", preferredStyle),
            line("Constraints", constraints),
            line("Nutrition", nutritionNotes),
            line("Movement", movementNotes),
            line("Sleep", sleepNotes),
            line("Values", values),
            line("What helps", whatHelps),
            line("What to avoid", whatToAvoid)
        ].compactMap { $0 }.joined(separator: "\n")
    }

    mutating func merge(from other: CoachUserProfile) {
        func prefer(_ incoming: String, over existing: String) -> String {
            let trimmed = incoming.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? existing : trimmed
        }
        preferredStyle = prefer(other.preferredStyle, over: preferredStyle)
        constraints = prefer(other.constraints, over: constraints)
        nutritionNotes = prefer(other.nutritionNotes, over: nutritionNotes)
        movementNotes = prefer(other.movementNotes, over: movementNotes)
        sleepNotes = prefer(other.sleepNotes, over: sleepNotes)
        values = prefer(other.values, over: values)
        whatHelps = prefer(other.whatHelps, over: whatHelps)
        whatToAvoid = prefer(other.whatToAvoid, over: whatToAvoid)
    }
}

struct CoachChatTurn: Identifiable, Equatable, Codable, Sendable {
    enum Role: String, Codable, Sendable {
        case user
        case coach
    }

    var id: UUID
    var role: Role
    var text: String
    var createdAt: Date

    init(id: UUID = UUID(), role: Role, text: String, createdAt: Date = Date()) {
        self.id = id
        self.role = role
        self.text = text
        self.createdAt = createdAt
    }
}

/// Compact facts for the model. Built by app code — never invent metrics in prompts.
struct CoachSnapshot: Equatable, Sendable {
    var todayKey: String
    var dayPhase: DayPhase
    var totalScore: Double
    var sleepHours: Double
    var sleepGoal: Double
    var sleepScore: Double
    var fiberGrams: Double
    var fiberGoal: Double
    var fiberScore: Double
    var exerciseMinutes: Double
    var exerciseGoal: Double
    var exerciseScore: Double
    var primaryFocus: PrimaryFocus
    var weekDaysWithData: Int
    var weekAvgScore: Double?
    var weekAvgSleep: Double?
    var weekAvgFiber: Double?
    var weekAvgExercise: Double?
    var fiberDaysLoggedInWeek: Int
    var sleepPresentToday: Bool
    var fiberPresentToday: Bool
    var exercisePresentToday: Bool

    var promptBlock: String {
        var lines: [String] = []
        lines.append("Date: \(todayKey)")
        lines.append("Day phase: \(dayPhase.rawValue)")
        lines.append(String(format: "Today score: %.1f / 10", totalScore))
        lines.append(
            String(
                format: "Sleep: %.1f h (goal %.1f, points %.1f/4)%@",
                sleepHours,
                sleepGoal,
                sleepScore,
                sleepPresentToday ? "" : " [no/low sleep data]"
            )
        )
        lines.append(
            String(
                format: "Fiber: %.1f g (goal %.0f, points %.1f/4)%@",
                fiberGrams,
                fiberGoal,
                fiberScore,
                fiberPresentToday ? "" : " [fiber logging incomplete/missing]"
            )
        )
        lines.append(
            String(
                format: "Exercise: %.0f min (goal %.0f, points %.1f/2)%@",
                exerciseMinutes,
                exerciseGoal,
                exerciseScore,
                exercisePresentToday ? "" : " [no exercise minutes logged]"
            )
        )
        lines.append("Implied focus from metrics: \(primaryFocus.rawValue)")
        lines.append(
            "Last 7 days: \(weekDaysWithData) days with records; fiber logged on \(fiberDaysLoggedInWeek)/7 days"
        )
        if let weekAvgScore {
            lines.append(String(format: "7-day avg score: %.1f", weekAvgScore))
        }
        if let weekAvgSleep {
            lines.append(String(format: "7-day avg sleep: %.1f h", weekAvgSleep))
        }
        if let weekAvgFiber {
            lines.append(String(format: "7-day avg fiber: %.1f g", weekAvgFiber))
        }
        if let weekAvgExercise {
            lines.append(String(format: "7-day avg exercise: %.0f min", weekAvgExercise))
        }
        lines.append(
            "Reminders: missing data ≠ failure; do not chase the score; one next step."
        )
        return lines.joined(separator: "\n")
    }
}

enum CoachAvailabilityStatus: Equatable {
    case available
    case deviceNotEligible
    case appleIntelligenceNotEnabled
    case modelNotReady
    case unavailable

    var title: String {
        switch self {
        case .available: return "Ready"
        case .deviceNotEligible: return "Device not eligible"
        case .appleIntelligenceNotEnabled: return "Apple Intelligence is off"
        case .modelNotReady: return "Model getting ready"
        case .unavailable: return "Coach unavailable"
        }
    }

    var guidance: String {
        switch self {
        case .available:
            return "DHS Lifestyle Coach is ready on this device."
        case .deviceNotEligible:
            return "DHS Lifestyle Coach needs an Apple Intelligence–capable iPhone on iOS 26."
        case .appleIntelligenceNotEnabled:
            return "Turn on Apple Intelligence in Settings to use DHS Lifestyle Coach."
        case .modelNotReady:
            return "Apple Intelligence is preparing the on-device model. Try again in a moment."
        case .unavailable:
            return "DHS Lifestyle Coach can’t run right now. Check Apple Intelligence and try again."
        }
    }
}
