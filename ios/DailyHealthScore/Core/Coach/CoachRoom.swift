import Foundation

/// Desks the same Coach works from. Inbox is "What's on my mind" until we file.
enum CoachRoom: String, CaseIterable, Codable, Sendable, Identifiable {
    case inbox
    case relationships
    case nutrition
    case sleep
    case activity
    case stress
    case hobbies

    var id: String { rawValue }

    /// The six Lifestyle Medicine desks. Inbox is filing, not a seventh identity.
    static var desks: [CoachRoom] {
        [.relationships, .nutrition, .sleep, .activity, .stress, .hobbies]
    }

    var label: String {
        switch self {
        case .inbox: return "What's on my mind"
        case .relationships: return "Relationships"
        case .nutrition: return "Nutrition"
        case .sleep: return "Sleep"
        case .activity: return "Physical Activity"
        case .stress: return "Stress Management"
        case .hobbies: return "Hobbies / Interests"
        }
    }

    var systemImage: String {
        switch self {
        case .inbox: return "bubble.left.and.text.bubble.right"
        case .relationships: return "heart"
        case .nutrition: return "leaf"
        case .sleep: return "moon.stars"
        case .activity: return "figure.run"
        case .stress: return "wind"
        case .hobbies: return "sparkles"
        }
    }

    /// Nutrition, sleep, and activity may mention today's Health once per clock window.
    var allowsUnpromptedHealth: Bool {
        self == .nutrition || self == .sleep || self == .activity
    }

    var isDesk: Bool { self != .inbox }

    static func from(focus: CoachFocusContext) -> CoachRoom {
        switch focus.feature {
        case .sleep, .hrv, .sleepDiagnostic: return .sleep
        case .fiber: return .nutrition
        case .exercise: return .activity
        case .today, .history, .goal: return .inbox
        }
    }
}

enum CoachThreadStatus: String, Codable, Sendable {
    case active
    case parked
}

struct CoachThread: Identifiable, Equatable, Codable, Sendable {
    var id: UUID
    var room: CoachRoom
    var title: String
    var status: CoachThreadStatus
    var createdAt: Date
    var updatedAt: Date
    var lastMessageAt: Date
    var healthMentionWindowKey: String
    var summary: String

    init(
        id: UUID = UUID(),
        room: CoachRoom,
        title: String,
        status: CoachThreadStatus = .active,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        lastMessageAt: Date = Date(),
        healthMentionWindowKey: String = "",
        summary: String = ""
    ) {
        self.id = id
        self.room = room
        self.title = title
        self.status = status
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.lastMessageAt = lastMessageAt
        self.healthMentionWindowKey = healthMentionWindowKey
        self.summary = summary
    }
}

struct CoachBridge: Identifiable, Equatable, Codable, Sendable {
    var id: UUID
    var text: String
    var fromRoom: CoachRoom
    var toRoom: CoachRoom
    var createdAt: Date
    var sourceThreadId: UUID

    init(
        id: UUID = UUID(),
        text: String,
        fromRoom: CoachRoom,
        toRoom: CoachRoom,
        createdAt: Date = Date(),
        sourceThreadId: UUID
    ) {
        self.id = id
        self.text = text
        self.fromRoom = fromRoom
        self.toRoom = toRoom
        self.createdAt = createdAt
        self.sourceThreadId = sourceThreadId
    }
}

/// Pure filing, parking, and naming. Rooms are doors, not fences.
enum CoachThreadLogic {
    static let parkAfter: TimeInterval = 36 * 3600
    static let inboxTurnsBeforeFile = 2

    static func isStale(_ thread: CoachThread, now: Date = Date()) -> Bool {
        guard thread.status == .active else { return false }
        return now.timeIntervalSince(thread.lastMessageAt) >= parkAfter
    }

    static func parkStale(_ threads: [CoachThread], now: Date = Date()) -> [CoachThread] {
        threads.map { thread in
            guard isStale(thread, now: now) else { return thread }
            var parked = thread
            parked.status = .parked
            parked.updatedAt = now
            return parked
        }
    }

    /// One Active desk per room. Starting a new episode parks the live one.
    static func parkActive(
        in room: CoachRoom,
        except exceptID: UUID? = nil,
        threads: [CoachThread],
        now: Date = Date()
    ) -> [CoachThread] {
        threads.map { thread in
            guard thread.room == room,
                  thread.status == .active,
                  thread.id != exceptID else { return thread }
            var parked = thread
            parked.status = .parked
            parked.updatedAt = now
            return parked
        }
    }

    static func active(in room: CoachRoom, threads: [CoachThread]) -> CoachThread? {
        threads
            .filter { $0.room == room && $0.status == .active }
            .sorted { $0.lastMessageAt > $1.lastMessageAt }
            .first
    }

    /// Most recent live episode, else the newest parked one — Home Continue.
    static func continueThread(in threads: [CoachThread]) -> CoachThread? {
        let live = threads.filter { $0.status == .active }.sorted { $0.lastMessageAt > $1.lastMessageAt }
        if let first = live.first { return first }
        return threads.sorted { $0.lastMessageAt > $1.lastMessageAt }.first
    }

    static func title(from userTexts: [String], room: CoachRoom) -> String {
        let joined = userTexts
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        guard !joined.isEmpty else { return room.label }
        let words = joined.split(whereSeparator: { $0.isWhitespace || $0.isNewline })
        let clipped = words.prefix(8).joined(separator: " ")
        if clipped.count <= 42 { return clipped }
        return String(clipped.prefix(41)).trimmingCharacters(in: .whitespaces) + "…"
    }

    /// Keyword filing. Inbox means "not sure yet."
    static func classify(_ text: String) -> CoachRoom {
        let t = text.lowercased()
        var scores: [CoachRoom: Int] = [:]
        func hit(_ room: CoachRoom, _ words: [String]) {
            for word in words where t.contains(word) {
                scores[room, default: 0] += 1
            }
        }
        hit(.relationships, [
            "wife", "husband", "partner", "spouse", "girlfriend", "boyfriend",
            "marriage", "we argued", "argument", "fight", "disagreement",
            "kids", "family", "friend", "lonely", "together"
        ])
        hit(.nutrition, [
            "eat", "ate", "food", "fiber", "meal", "lunch", "dinner", "breakfast",
            "hungry", "snack", "protein", "vegetable", "beans", "overeat", "craving"
        ])
        hit(.sleep, [
            "sleep", "slept", "tired", "insomnia", "bed", "awake", "nap",
            "caffeine", "wind-down", "wind down"
        ])
        hit(.activity, [
            "walk", "run", "workout", "exercise", "lift", "strength", "bike",
            "hike", "movement", "steps", "training"
        ])
        hit(.stress, [
            "stress", "anxious", "anxiety", "overwhelm", "panic", "urge",
            "breathing", "calm", "worried"
        ])
        hit(.hobbies, [
            "hobby", "hobbies", "guitar", "garden", "cooking for fun", "game",
            "music", "paint", "fishing", "interest", "for fun"
        ])
        let best = scores.max { lhs, rhs in
            if lhs.value != rhs.value { return lhs.value < rhs.value }
            return lhs.key.rawValue > rhs.key.rawValue
        }
        guard let best, best.value > 0 else { return .inbox }
        return best.key
    }

    /// File inbox after two user turns. Refile a desk when the latest talk
    /// clearly lives elsewhere. Follow the person; do not drag them back.
    static func filingDecision(
        room: CoachRoom,
        userTexts: [String],
        latestUserText: String
    ) -> CoachRoom? {
        let latest = classify(latestUserText)
        if room == .inbox {
            guard userTexts.count >= inboxTurnsBeforeFile else { return nil }
            let combined = classify(userTexts.suffix(inboxTurnsBeforeFile).joined(separator: " "))
            return combined == .inbox ? nil : combined
        }
        if latest != .inbox, latest != room {
            return latest
        }
        return nil
    }

    static func bridgeText(from: CoachRoom, to: CoachRoom, title: String) -> String {
        if from == .inbox {
            return "This conversation is now on the \(to.label) desk: \(title)."
        }
        return "Moved from \(from.label) to \(to.label): \(title)."
    }

    static func healthWindowKey(now: Date = Date(), calendar: Calendar = .current) -> String {
        let day = WatchBridge.localDateKey(from: now, calendar: calendar)
        return "\(day)#\(CoachTimeOfDay.current(from: now, calendar: calendar).rawValue)"
    }

    static func shouldMentionHealth(
        room: CoachRoom,
        alreadyMentionedInWindow: Bool,
        userAskedAboutNumbers: Bool
    ) -> Bool {
        if userAskedAboutNumbers { return true }
        guard room.allowsUnpromptedHealth else { return false }
        return !alreadyMentionedInWindow
    }
}

enum CoachChatLaunch: Equatable, Identifiable {
    case recents
    case inbox
    case continueThread
    case room(CoachRoom)
    case thread(UUID)
    case focus(CoachFocusContext)

    var id: String {
        switch self {
        case .recents: return "recents"
        case .inbox: return "inbox"
        case .continueThread: return "continue"
        case .room(let room): return "room-\(room.rawValue)"
        case .thread(let id): return "thread-\(id.uuidString)"
        case .focus(let focus): return "focus-\(focus.id.uuidString)"
        }
    }
}
