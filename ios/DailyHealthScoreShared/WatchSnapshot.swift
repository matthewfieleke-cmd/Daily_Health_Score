import Foundation

/// Compact today-state the Watch can show and nudge from.
///
/// Built on the iPhone from Apple Health + SMART goals. The Watch never
/// recomputes the 10-point score; it displays this snapshot and sends check-ins
/// back for the iPhone to merge.
struct WatchSnapshot: Codable, Equatable, Sendable {
    var dateKey: String
    var totalScore: Double
    var sleep: WatchPillarSnapshot
    var fiber: WatchPillarSnapshot
    var exercise: WatchPillarSnapshot
    var goals: [WatchGoalSnapshot]
    var updatedAt: Date
    var paceNudgesEnabled: Bool

    var pillars: [WatchPillarSnapshot] { [sleep, fiber, exercise] }

    var scoreFraction: Double {
        max(0, min(totalScore / 10, 1))
    }

    var formattedScore: String {
        String(format: "%.1f", (totalScore * 10).rounded() / 10)
    }

    /// One-line pillar summary for the rectangular Watch face slot.
    var rectangularPillarLine: String {
        "S \(sleep.compactFaceValue)  F \(fiber.compactFaceValue)  E \(exercise.compactFaceValue)"
    }

    var rectangularPillarLineSleepFiber: String {
        "S \(sleep.compactFaceValue)  F \(fiber.compactFaceValue)"
    }

    var rectangularPillarLineExercise: String {
        "E \(exercise.compactFaceValue)"
    }

    var rectangularAccessibilityLine: String {
        "Sleep \(sleep.compactFaceValue), fiber \(fiber.compactFaceValue), exercise \(exercise.compactFaceValue)"
    }

    func isForDay(_ date: Date, calendar: Calendar = .current) -> Bool {
        dateKey == WatchBridge.localDateKey(from: date, calendar: calendar)
    }
}

struct WatchPillarSnapshot: Codable, Equatable, Sendable {
    var name: String
    var value: Double
    var goal: Double
    var unit: String
    var points: Double
    var maxPoints: Double

    var formattedValue: String {
        if unit == "min" {
            return "\(Int(value.rounded()))"
        }
        let rounded = (value * 10).rounded() / 10
        if rounded == rounded.rounded(.towardZero) {
            return String(format: "%.0f", rounded)
        }
        return String(format: "%.1f", rounded)
    }

    var formattedGoal: String {
        if unit == "min" || unit == "g" {
            return "\(Int(goal.rounded()))"
        }
        let rounded = (goal * 10).rounded() / 10
        if rounded == rounded.rounded(.towardZero) {
            return String(format: "%.0f", rounded)
        }
        return String(format: "%.1f", rounded)
    }

    var formattedPoints: String {
        let rounded = (points * 10).rounded() / 10
        let maxRounded = (maxPoints * 10).rounded() / 10
        return "\(formatOnePlace(rounded)) / \(formatOnePlace(maxRounded))"
    }

    /// Short unit suffix for the rectangular complication: 5.4h, 12g, 8m.
    var compactFaceValue: String {
        switch unit {
        case "hr", "h", "hours":
            return "\(formattedValue)h"
        case "g", "gram", "grams":
            return "\(formattedValue)g"
        case "min", "m", "minutes":
            return "\(formattedValue)m"
        default:
            return "\(formattedValue)\(unit)"
        }
    }

    private func formatOnePlace(_ value: Double) -> String {
        value == value.rounded(.towardZero) ? String(format: "%.0f", value) : String(format: "%.1f", value)
    }
}

struct WatchGoalSnapshot: Codable, Equatable, Identifiable, Sendable {
    var id: UUID
    var specificText: String
    var targetCount: Int
    var filledMask: Int
    var statusRaw: String

    var filledCount: Int {
        (0 ..< targetCount).filter { isFilled($0) }.count
    }

    var isComplete: Bool { filledCount >= targetCount }

    var isActive: Bool { statusRaw == "active" && !isComplete }

    func isFilled(_ index: Int) -> Bool {
        guard index >= 0, index < targetCount else { return false }
        return (filledMask & (1 << index)) != 0
    }

    /// Fills the lowest empty circle. Returns false when there is nothing to fill.
    @discardableResult
    mutating func fillNextEmpty() -> Bool {
        guard isActive, targetCount > 0 else { return false }
        for index in 0 ..< targetCount where !isFilled(index) {
            filledMask |= (1 << index)
            return true
        }
        return false
    }
}

/// Watch-side merge: keep in-flight local taps (bit OR) until the iPhone snapshot
/// includes those bits. Missing / ended goals are whatever the iPhone sent.
enum WatchCheckInMerge {
    static func apply(
        current: WatchSnapshot?,
        incoming: WatchSnapshot,
        pendingFills: [UUID: Int]
    ) -> (snapshot: WatchSnapshot, pendingFills: [UUID: Int]) {
        guard let current else { return (incoming, pendingFills) }
        var pending = pendingFills
        var result = incoming
        for index in result.goals.indices {
            let id = result.goals[index].id
            guard pending[id, default: 0] > 0,
                  let local = current.goals.first(where: { $0.id == id }) else { continue }
            let incomingMask = result.goals[index].filledMask
            result.goals[index].filledMask = incomingMask | local.filledMask
            if (incomingMask & local.filledMask) == local.filledMask {
                pending[id] = nil
            }
        }
        return (result, pending)
    }
}

/// One "fill the next empty circle" event from the Watch. The iPhone applies it
/// against live SwiftData so two in-flight taps cannot clobber each other.
struct WatchCheckInEvent: Codable, Equatable, Sendable {
    var goalId: UUID
    var createdAt: Date
}
