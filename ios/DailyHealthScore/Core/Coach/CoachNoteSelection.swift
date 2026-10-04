import Foundation

/// Which saved notes a strong model is allowed to see. The model returns ids.
/// The writer then sees only those notes. A miss, a timeout, or an empty
/// choice attaches nothing: word overlap is not a fallback.
enum CoachNoteSelection {
    enum Read: Equatable {
        case notes(String)
        case none
        case unread
    }

    static let emptyIndex = "None."
    static let savedNotesHeader = "Saved notes:"
    static let otherChatsHeader = "Other chats:"
    static let noMatchMessage = "No saved notes match this topic."
    static let unreadMessage = "That topic could not be looked up just now."
    static let noneForCard = "None for this card."
    static let noSavedNotes = "No saved notes."
    static let replyLimit = 8
    static let cardLimit = 4
    static let characterBudget = 8_000

    static func replyRequest(message: String, earlier: String, situation: String) -> String {
        [message, earlier.isEmpty ? "" : "Just before, they said: \(earlier)", situation]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n\n")
            .limitedToCoachBudget(2_000)
    }

    /// The moment, without today's numbers. The card already shows those.
    static func homeCardRequest(clockLabel: String, weakestPillar: String?) -> String {
        let room = weakestPillar.map { "The pillar with the most room right now is \($0). " }
            ?? "All three pillars have room. "
        return "A short Home card, \(clockLabel). \(room)Today's numbers are already on screen above the card. Which notes would change what is worth saying?"
    }

    static func prompt(request: String, index: String) -> String {
        """
        WHAT THIS ANSWER IS FOR:
        \(request)

        NOTES:
        \(index)
        """
    }

    /// One line per note, balanced across files so a long Recent list cannot
    /// hide a durable fact. Recent chats, when present, follow the notes.
    static func index(
        items: [CoachMemoryItem],
        conversations: String = "",
        at date: Date = Date(),
        calendar: Calendar = .current,
        characterBudget: Int = characterBudget
    ) -> String {
        let chats = conversationEntries(conversations)
        let reserve = chats.isEmpty ? 0 : min(600, max(characterBudget / 5, 0))
        let noteBudget = max(characterBudget - reserve, 1)
        let notes = CoachMemoryLogic.compilerEntryList(
            items: items,
            at: date,
            calendar: calendar,
            characterBudget: noteBudget
        )
        var lines: [String] = []
        if notes != "None." {
            lines.append(contentsOf: notes.split(separator: "\n", omittingEmptySubsequences: true).map(String.init))
        }
        var used = lines.reduce(0) { $0 + $1.count + 1 }
        for (offset, chat) in chats.enumerated() {
            let line = "chat\(offset + 1) | chat | \(chat)"
            let cost = line.count + (lines.isEmpty ? 0 : 1)
            if used + cost > characterBudget { break }
            lines.append(line)
            used += cost
        }
        return lines.isEmpty ? emptyIndex : lines.joined(separator: "\n")
    }

    /// Ids the model returned, in its order, without duplicates or blanks.
    static func normalizedIDs(_ raw: [String]) -> [String] {
        var seen = Set<String>()
        var ids: [String] = []
        for value in raw {
            guard let id = firstIdentifier(in: value) else { continue }
            if seen.insert(id).inserted {
                ids.append(id)
            }
        }
        return ids
    }

    /// Full text for the writer, in the order the ids were chosen. File
    /// headings stay out: a heading reads like an assignment.
    static func writerBlock(
        chosenIDs: [String],
        items: [CoachMemoryItem],
        conversations: String = "",
        at date: Date = Date(),
        calendar: Calendar = .current,
        limit: Int = replyLimit
    ) -> String {
        let ids = Array(normalizedIDs(chosenIDs).prefix(max(limit, 0)))
        guard !ids.isEmpty else { return "" }
        let live = CoachMemoryLogic.itemsByOverridingContradictions(items, at: date)
        let chats = conversationEntries(conversations)
        var notes: [String] = []
        var chatLines: [String] = []
        for id in ids {
            if id.hasPrefix("chat"),
               let number = Int(id.dropFirst(4)),
               chats.indices.contains(number - 1) {
                chatLines.append(chats[number - 1])
                continue
            }
            guard let item = live.first(where: { $0.id.uuidString.lowercased().hasPrefix(id) }) else { continue }
            notes.append(CoachMemoryLogic.datedNoteLine(for: item, at: date, calendar: calendar))
        }
        var parts: [String] = []
        if !notes.isEmpty {
            parts.append(savedNotesHeader + "\n" + notes.joined(separator: "\n"))
        }
        if !chatLines.isEmpty {
            parts.append(otherChatsHeader + "\n" + chatLines.joined(separator: "\n"))
        }
        return parts.joined(separator: "\n\n")
    }

    static func conversationEntries(_ block: String) -> [String] {
        let trimmed = block.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty || trimmed == "None yet." { return [] }
        return trimmed.split(separator: "\n", omittingEmptySubsequences: true).compactMap { raw in
            var text = String(raw).trimmingCharacters(in: .whitespaces)
            if text.hasPrefix("- ") { text.removeFirst(2) }
            return text.isEmpty ? nil : text
        }
    }

    private static func firstIdentifier(in value: String) -> String? {
        let token = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if token.isEmpty || token == "none" || token == "n/a" || token == "null" || token == "nil" {
            return nil
        }
        if token.hasPrefix("chat") {
            let rest = token.dropFirst(4)
            let digits = rest.prefix(while: \.isNumber)
            if let number = Int(digits), (1...99).contains(number) {
                let after = rest.dropFirst(digits.count)
                if after.isEmpty || after.hasPrefix(" ") || after.hasPrefix("|") || after.hasPrefix(":") {
                    return "chat\(number)"
                }
            }
        }
        var hex = ""
        for character in token {
            if character.isHexDigit {
                hex.append(character)
                if hex.count == 8 { return hex }
            } else {
                hex = ""
            }
        }
        return nil
    }
}
