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
        guard !isComplete, targetCount > 0 else { return false }
        for index in 0 ..< targetCount where !isFilled(index) {
            filledMask |= (1 << index)
            return true
        }
        return false
    }
}

/// One "fill the next empty circle" event from the Watch. The iPhone applies it
/// against live SwiftData so two in-flight taps cannot clobber each other.
struct WatchCheckInEvent: Codable, Equatable, Sendable {
    var goalId: UUID
    var createdAt: Date
}
