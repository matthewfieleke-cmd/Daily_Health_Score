import Foundation

/// Lifestyle Medicine pillar the Coach is attending to in a chat.
///
/// An internal tag, never a room: it steers whether a reply leads with numbers
/// or with feelings, where a memory note is filed, and which glyph a chat row
/// wears. The person only ever sees one flat list of chats.
enum CoachPillar: String, CaseIterable, Codable, Sendable, Identifiable {
    case general
    case relationships
    case nutrition
    case sleep
    case activity
    case stress
    case hobbies

    var id: String { rawValue }

    /// Build 19 stored the untagged pillar as "inbox". Keep those rows readable.
    init(storageValue: String) {
        if storageValue == "inbox" {
            self = .general
        } else {
            self = CoachPillar(rawValue: storageValue) ?? .general
        }
    }

    /// Model output is free text; accept labels, raw values, and near misses.
    init(modelValue: String) {
        let text = modelValue.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        if text.isEmpty { self = .general; return }
        if let exact = CoachPillar(rawValue: text) { self = exact; return }
        let words = Set(text.components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty })
        func has(_ stems: String...) -> Bool {
            words.contains { word in stems.contains { word.hasPrefix($0) } }
        }
        if has("relation", "connection", "family", "partner", "marriage") {
            self = .relationships
        } else if has("hobb", "interest", "play", "fun", "creativ") {
            self = .hobbies
        } else if has("nutri", "food", "eat", "diet", "fiber") {
            self = .nutrition
        } else if has("activ", "exercis", "movement", "fitness", "walk", "train") {
            self = .activity
        } else if has("stress", "anxi", "mood", "overwhelm", "calm") {
            self = .stress
        } else if has("sleep", "rest", "insomnia", "bedtime") {
            self = .sleep
        } else {
            self = .general
        }
    }

    var label: String {
        switch self {
        case .general: return "General"
        case .relationships: return "Relationships"
        case .nutrition: return "Nutrition"
        case .sleep: return "Sleep"
        case .activity: return "Physical Activity"
        case .stress: return "Stress"
        case .hobbies: return "Hobbies & Interests"
        }
    }

    var systemImage: String {
        switch self {
        case .general: return "bubble.left.and.text.bubble.right.fill"
        case .relationships: return "heart.fill"
        case .nutrition: return "leaf.fill"
        case .sleep: return "moon.stars.fill"
        case .activity: return "figure.run"
        case .stress: return "wind"
        case .hobbies: return "sparkles"
        }
    }

    /// Nutrition, sleep, and activity chats lead with the person's numbers.
    /// Everything else leads with the person.
    var leadsWithNumbers: Bool {
        self == .nutrition || self == .sleep || self == .activity
    }

    static func from(focus: CoachFocusContext) -> CoachPillar {
        switch focus.feature {
        case .sleep, .hrv, .sleepDiagnostic: return .sleep
        case .fiber: return .nutrition
        case .exercise: return .activity
        case .today, .history, .goal: return .general
        }
    }

    static func from(primaryFocus: PrimaryFocus) -> CoachPillar {
        switch primaryFocus {
        case .sleep: return .sleep
        case .fiber: return .nutrition
        case .exercise: return .activity
        case .maintain: return .general
        }
    }
}

/// Why a chat exists. Changes the Coach's stance, not the person's view of it.
enum CoachThreadKind: String, Codable, Sendable {
    /// Anything the person opened themselves.
    case conversation
    /// The first "let's get acquainted" conversation.
    case acquaintance
    /// Opened by tapping Reply on a Home check-in.
    case checkInReply
    /// Opened from a SMART goal.
    case goal
}

struct CoachThread: Identifiable, Equatable, Codable, Sendable {
    var id: UUID
    var pillar: CoachPillar
    var kind: CoachThreadKind
    var title: String
    /// True until the Coach has named the chat itself.
    var titleIsProvisional: Bool
    /// Last message, one line, Markdown stripped.
    var preview: String
    var messageCount: Int
    var createdAt: Date
    var updatedAt: Date
    var lastMessageAt: Date
    var healthMentionWindowKey: String
    /// One sentence the Coach wrote about where this chat stands; feeds callbacks.
    var summary: String
    /// Where the chat started (a metric, a goal, a check-in). Prompt-only.
    var contextNote: String
    var goalId: UUID?

    init(
        id: UUID = UUID(),
        pillar: CoachPillar = .general,
        kind: CoachThreadKind = .conversation,
        title: String,
        titleIsProvisional: Bool = true,
        preview: String = "",
        messageCount: Int = 0,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        lastMessageAt: Date = Date(),
        healthMentionWindowKey: String = "",
        summary: String = "",
        contextNote: String = "",
        goalId: UUID? = nil
    ) {
        self.id = id
        self.pillar = pillar
        self.kind = kind
        self.title = title
        self.titleIsProvisional = titleIsProvisional
        self.preview = preview
        self.messageCount = messageCount
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.lastMessageAt = lastMessageAt
        self.healthMentionWindowKey = healthMentionWindowKey
        self.summary = summary
        self.contextNote = contextNote
        self.goalId = goalId
    }
}

/// Where a chat row sits in the list.
enum CoachThreadGroup: Int, CaseIterable, Sendable {
    case today
    case yesterday
    case thisWeek
    case earlier

    var title: String {
        switch self {
        case .today: return "Today"
        case .yesterday: return "Yesterday"
        case .thisWeek: return "This Week"
        case .earlier: return "Earlier"
        }
    }
}

struct CoachThreadSection: Equatable, Identifiable {
    var group: CoachThreadGroup
    var threads: [CoachThread]
    var id: Int { group.rawValue }
}

/// Pure list, naming, and timing rules. No SwiftData, no model calls.
enum CoachThreadLogic {
    static let maxTitleCharacters = 40
    static let maxTitleWords = 7
    static let previewCharacters = 120

    static func sorted(_ threads: [CoachThread]) -> [CoachThread] {
        threads.sorted { $0.lastMessageAt > $1.lastMessageAt }
    }

    static func group(
        for thread: CoachThread,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> CoachThreadGroup {
        let day = calendar.startOfDay(for: thread.lastMessageAt)
        let today = calendar.startOfDay(for: now)
        if day >= today { return .today }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: today), day >= yesterday {
            return .yesterday
        }
        if let weekAgo = calendar.date(byAdding: .day, value: -6, to: today), day >= weekAgo {
            return .thisWeek
        }
        return .earlier
    }

    static func sections(
        _ threads: [CoachThread],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> [CoachThreadSection] {
        let visible = sorted(threads).filter { $0.messageCount > 0 }
        return CoachThreadGroup.allCases.compactMap { group in
            let rows = visible.filter { self.group(for: $0, now: now, calendar: calendar) == group }
            return rows.isEmpty ? nil : CoachThreadSection(group: group, threads: rows)
        }
    }

    /// Messages-style timestamp: clock today, "Yesterday", weekday this week, else a short date.
    static func timeLabel(
        for date: Date,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> String {
        let probe = CoachThread(title: "", lastMessageAt: date)
        switch group(for: probe, now: now, calendar: calendar) {
        case .today:
            return date.formatted(.dateTime.hour().minute())
        case .yesterday:
            return "Yesterday"
        case .thisWeek:
            return date.formatted(.dateTime.weekday(.wide))
        case .earlier:
            return date.formatted(.dateTime.month(.abbreviated).day())
        }
    }

    /// Placeholder until the Coach names the chat: the person's first few words.
    static func provisionalTitle(from userText: String, fallback: String = "New chat") -> String {
        let cleaned = userText
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return fallback }
        let words = cleaned.split(whereSeparator: { $0.isWhitespace }).map(String.init)
        var title = words.prefix(6).joined(separator: " ")
        while title.last.map({ ".,;:!?".contains($0) }) == true {
            title.removeLast()
        }
        if title.count > maxTitleCharacters {
            title = String(title.prefix(maxTitleCharacters))
            if let space = title.lastIndex(of: " ") {
                title = String(title[..<space])
            }
        }
        let first = title.prefix(1).uppercased()
        return first + title.dropFirst()
    }

    /// Cleans a model-written title. Nil means "keep what we have".
    static func sanitizedTitle(_ raw: String) -> String? {
        var title = raw
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "*", with: "")
            .replacingOccurrences(of: "#", with: "")
            .replacingOccurrences(of: "\"", with: "")
            .replacingOccurrences(of: "“", with: "")
            .replacingOccurrences(of: "”", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        while title.last.map({ ".!?:;,".contains($0) }) == true {
            title.removeLast()
        }
        title = title.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
        guard !title.isEmpty else { return nil }
        let words = title.split(separator: " ")
        guard words.count <= maxTitleWords else { return nil }
        if title.count > maxTitleCharacters { return nil }
        let lowered = title.lowercased()
        if lowered == "new chat" || lowered == "chat" || lowered == "conversation" { return nil }
        return title
    }

    /// One-line preview for the chat row, Markdown markers removed.
    static func preview(from text: String) -> String {
        let plain = CoachMarkdown.plainText(text)
            .replacingOccurrences(of: "\n", with: " ")
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
        guard plain.count > previewCharacters else { return plain }
        let cut = String(plain.prefix(previewCharacters))
        if let space = cut.lastIndex(of: " ") {
            return String(cut[..<space]) + "…"
        }
        return cut + "…"
    }

    static func healthWindowKey(now: Date = Date(), calendar: Calendar = .current) -> String {
        let day = WatchBridge.localDateKey(from: now, calendar: calendar)
        return "\(day)#\(CoachTimeOfDay.current(from: now, calendar: calendar).rawValue)"
    }

    /// Nutrition, sleep, and activity chats may bring up today's Health once per
    /// clock window without being asked. Other chats only when asked.
    static func shouldMentionHealth(
        pillar: CoachPillar,
        alreadyMentionedInWindow: Bool,
        userAskedAboutNumbers: Bool
    ) -> Bool {
        if userAskedAboutNumbers { return true }
        guard pillar.leadsWithNumbers else { return false }
        return !alreadyMentionedInWindow
    }

    /// Recent chats as facts for the prompt, so the Coach can call back to them.
    static func recentConversationsBlock(
        _ threads: [CoachThread],
        excluding openID: UUID?,
        now: Date = Date(),
        calendar: Calendar = .current,
        limit: Int = 4
    ) -> String {
        let rows = sorted(threads)
            .filter { $0.id != openID && $0.messageCount > 0 && !$0.summary.isEmpty }
            .prefix(limit)
        guard !rows.isEmpty else { return "None yet." }
        return rows.map { thread in
            let when = relativeDays(from: thread.lastMessageAt, to: now, calendar: calendar)
            return "- \(when): \"\(thread.title)\" — \(thread.summary)"
        }.joined(separator: "\n")
    }

    static func relativeDays(from date: Date, to now: Date, calendar: Calendar = .current) -> String {
        let days = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: date),
            to: calendar.startOfDay(for: now)
        ).day ?? 0
        switch days {
        case ..<1: return "Today"
        case 1: return "Yesterday"
        case 2...6: return "\(days) days ago"
        case 7...13: return "Last week"
        default: return "\(days / 7) weeks ago"
        }
    }
}

/// How a chat sheet was opened. Blank launches create their thread on the
/// first message, so tapping in and backing out never leaves an empty row.
enum CoachChatLaunch: Equatable, Identifiable {
    /// The chats list.
    case chats
    /// A blank chat.
    case newChat
    /// A blank chat with the composer prefilled.
    case compose(String)
    /// The first "let's get acquainted" conversation.
    case acquaint
    /// Reply to the current Home check-in.
    case replyToCheckIn
    /// A chat seeded with a metric or a selected period.
    case focus(CoachFocusContext)
    /// A chat about one saved SMART goal.
    case goal(UUID)
    /// Reopen an existing chat.
    case thread(UUID)

    var id: String {
        switch self {
        case .chats: return "chats"
        case .newChat: return "new"
        case .compose(let text): return "compose-\(text.hashValue)"
        case .acquaint: return "acquaint"
        case .replyToCheckIn: return "check-in-reply"
        case .focus(let focus): return "focus-\(focus.id.uuidString)"
        case .goal(let id): return "goal-\(id.uuidString)"
        case .thread(let id): return "thread-\(id.uuidString)"
        }
    }
}
