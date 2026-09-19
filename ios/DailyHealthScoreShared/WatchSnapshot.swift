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

    /// Complication and glance UI must not paint yesterday under a Today label.
    static func currentIfToday(
        _ snapshot: WatchSnapshot?,
        at date: Date = Date(),
        calendar: Calendar = .current
    ) -> WatchSnapshot? {
        guard let snapshot, snapshot.isForDay(date, calendar: calendar) else { return nil }
        return snapshot
    }

    /// Complication views should show the newest today-snapshot they can see:
    /// the WidgetKit entry, or the App Group file the Watch app just wrote.
    static func newestCurrent(
        _ first: WatchSnapshot?,
        _ second: WatchSnapshot?,
        at date: Date = Date(),
        calendar: Calendar = .current
    ) -> WatchSnapshot? {
        let a = displayable(first, at: date, calendar: calendar)
        let b = displayable(second, at: date, calendar: calendar)
        switch (a, b) {
        case let (a?, b?):
            return a.updatedAt >= b.updatedAt ? a : b
        case let (a?, nil):
            return a
        case let (nil, b?):
            return b
        default:
            return nil
        }
    }

    /// Face paint order: a today-snapshot, then any snapshot written in the last
    /// 18 hours. Widget calendars can disagree with the iPhone `dateKey`; that
    /// must not keep "-- / Open iPhone" on a slot that already has bytes.
    static func preferredForFace(
        _ first: WatchSnapshot?,
        _ second: WatchSnapshot? = nil,
        at date: Date = Date(),
        calendar: Calendar = .current,
        recentInterval: TimeInterval = 18 * 3600
    ) -> WatchSnapshot? {
        if let shown = newestCurrent(first, second, at: date, calendar: calendar) {
            return shown
        }
        let recent = [first, second].compactMap { $0 }.filter { snapshot in
            let age = date.timeIntervalSince(snapshot.updatedAt)
            return age >= -3600 && age <= recentInterval
        }
        return recent.max(by: { $0.updatedAt < $1.updatedAt })
    }

    /// Prefer a matching dateKey. If the widget calendar disagrees with the
    /// iPhone dateKey, still show a snapshot written the same local day so the
    /// face does not stay on Open iPhone.
    static func displayable(
        _ snapshot: WatchSnapshot?,
        at date: Date = Date(),
        calendar: Calendar = .current
    ) -> WatchSnapshot? {
        guard let snapshot else { return nil }
        if snapshot.isForDay(date, calendar: calendar) { return snapshot }
        if calendar.isDate(snapshot.updatedAt, inSameDayAs: date) { return snapshot }
        return nil
    }

    /// Pipe-delimited face line the widget can parse even if JSON decode fails.
    var compactFaceRecord: String {
        [
            dateKey,
            formattedScore,
            String(sleep.value),
            sleep.unit,
            String(fiber.value),
            fiber.unit,
            String(exercise.value),
            exercise.unit,
            String(Int(updatedAt.timeIntervalSince1970))
        ].joined(separator: "|")
    }

    static func fromCompactFaceRecord(_ line: String) -> WatchSnapshot? {
        let parts = line.split(separator: "|", omittingEmptySubsequences: false).map(String.init)
        guard parts.count >= 9 else { return nil }
        guard let sleepValue = Double(parts[2]),
              let fiberValue = Double(parts[4]),
              let exerciseValue = Double(parts[6]),
              let score = Double(parts[1]),
              let updated = TimeInterval(parts[8]) else { return nil }
        return WatchSnapshot(
            dateKey: parts[0],
            totalScore: score,
            sleep: WatchPillarSnapshot(
                name: "Sleep", value: sleepValue, goal: 7.5, unit: parts[3], points: 0, maxPoints: 4
            ),
            fiber: WatchPillarSnapshot(
                name: "Fiber", value: fiberValue, goal: 40, unit: parts[5], points: 0, maxPoints: 4
            ),
            exercise: WatchPillarSnapshot(
                name: "Exercise", value: exerciseValue, goal: 30, unit: parts[7], points: 0, maxPoints: 2
            ),
            goals: [],
            updatedAt: Date(timeIntervalSince1970: updated),
            paceNudgesEnabled: true
        )
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
/// `eventId` is stable across Watch Connectivity retries. `createdAt` is when
/// the person tapped — not when the iPhone later received the message.
struct WatchCheckInEvent: Codable, Equatable, Sendable {
    var eventId: UUID
    var goalId: UUID
    var createdAt: Date

    init(eventId: UUID = UUID(), goalId: UUID, createdAt: Date) {
        self.eventId = eventId
        self.goalId = goalId
        self.createdAt = createdAt
    }

    private enum CodingKeys: String, CodingKey {
        case eventId, goalId, createdAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        goalId = try container.decode(UUID.self, forKey: .goalId)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        eventId = try container.decodeIfPresent(UUID.self, forKey: .eventId)
            ?? Self.legacyEventId(goalId: goalId, createdAt: createdAt)
    }

    /// Stable identity for older Watch payloads that only sent goalId + createdAt.
    static func legacyEventId(goalId: UUID, createdAt: Date) -> UUID {
        var uuid = goalId.uuid
        let micros = Int64((createdAt.timeIntervalSince1970 * 1_000_000).rounded())
        let t = UInt64(bitPattern: micros)
        uuid.8 ^= UInt8(truncatingIfNeeded: t >> 56)
        uuid.9 ^= UInt8(truncatingIfNeeded: t >> 48)
        uuid.10 ^= UInt8(truncatingIfNeeded: t >> 40)
        uuid.11 ^= UInt8(truncatingIfNeeded: t >> 32)
        uuid.12 ^= UInt8(truncatingIfNeeded: t >> 24)
        uuid.13 ^= UInt8(truncatingIfNeeded: t >> 16)
        uuid.14 ^= UInt8(truncatingIfNeeded: t >> 8)
        uuid.15 ^= UInt8(truncatingIfNeeded: t)
        return UUID(uuid: uuid)
    }
}
