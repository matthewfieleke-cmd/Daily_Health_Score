import Foundation

/// Pulls durable facts a Lifestyle Medicine coach with exercise-science,
/// nutrition, and behavioral-psychology training would write down — from the
/// person's own words, not from today's score.
enum CoachPhDMemoryExtractor {
    /// A long message is filed one sentence at a time, so a paragraph about work,
    /// eating, and a marriage does not land in three files as one block.
    static func items(from message: String, now: Date = Date()) -> [CoachMemoryItem] {
        let sentences = message
            .replacingOccurrences(of: "\n", with: " ")
            .components(separatedBy: CharacterSet(charactersIn: ".!?"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.count >= 8 }
        let sources = sentences.count > 1 ? sentences : [message.trimmingCharacters(in: .whitespacesAndNewlines)]
        var all: [CoachMemoryItem] = []
        var seen = Set<String>()
        for sentence in sources {
            for item in items(fromSentence: sentence, now: now)
            where seen.insert("\(item.category.rawValue)#\(item.contentFingerprint)").inserted {
                all.append(item)
            }
        }
        return all
    }

    private static func items(fromSentence sentence: String, now: Date) -> [CoachMemoryItem] {
        let trimmed = sentence.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 8 else { return [] }
        let lower = trimmed.lowercased()
        var items: [CoachMemoryItem] = []

        if looksLikeEmotionalEating(lower) {
            items.append(stated(.trigger, trimmed, now: now))
        }
        if looksLikeRelationshipStress(lower) {
            items.append(stated(.relationship, trimmed, now: now))
        }
        if looksLikeRecoveryConstraint(lower) {
            items.append(stated(.recovery, trimmed, now: now, temporary: true))
        }
        if looksLikeIdentity(lower) {
            items.append(stated(.identity, trimmed, now: now))
        }
        if looksLikeStressLoad(lower) && !looksLikeEmotionalEating(lower) {
            items.append(stated(.stress, trimmed, now: now))
        }

        // One sentence can belong in two files (a trigger and a relationship);
        // dedupe per file, not per sentence.
        var unique: [CoachMemoryItem] = []
        var seen = Set<String>()
        for item in items where seen.insert("\(item.category.rawValue)#\(item.contentFingerprint)").inserted {
            unique.append(item)
        }
        return unique
    }

    private static func stated(
        _ category: CoachMemoryCategory,
        _ content: String,
        now: Date,
        temporary: Bool = false
    ) -> CoachMemoryItem {
        CoachMemoryItem(
            category: category,
            content: String(content.prefix(CoachUserProfile.maxFieldLength)),
            provenance: .userStated,
            createdAt: now,
            lastConfirmedAt: now,
            expiresAt: temporary ? now.addingTimeInterval(14 * 86_400) : nil,
            confirmation: .confirmed,
            isTemporary: temporary
        )
    }

    static func looksLikeEmotionalEating(_ lower: String) -> Bool {
        let eating = lower.contains("overeat") || lower.contains("binge")
            || lower.contains("emotional eat") || lower.contains("eat when")
            || lower.contains("eating when")
        let trigger = lower.contains("when") || lower.contains("after")
            || lower.contains("whenever")
        return eating && trigger
    }

    static func looksLikeRelationshipStress(_ lower: String) -> Bool {
        let person = lower.contains("wife") || lower.contains("husband")
            || lower.contains("partner") || lower.contains("spouse")
            || lower.contains("kids") || lower.contains("children")
        let friction = lower.contains("disagree") || lower.contains("argument")
            || lower.contains("arguing") || lower.contains("fight")
            || lower.contains("conflict") || lower.contains("we fought")
        return person && friction
    }

    static func looksLikeRecoveryConstraint(_ lower: String) -> Bool {
        let cues = [
            "injured", "injury", "sprain", "sprained", "sore knee", "bad back",
            "hurt my", "physical therapy", "broken ", "fracture"
        ]
        return cues.contains { lower.contains($0) }
    }

    static func looksLikeIdentity(_ lower: String) -> Bool {
        lower.contains("i am someone who")
            || lower.contains("i'm someone who")
            || lower.contains("i'm not a")
            || lower.contains("i am not a")
    }

    static func looksLikeStressLoad(_ lower: String) -> Bool {
        let cues = ["overwhelmed", "burned out", "burnt out", "so stressed", "can't keep up", "cant keep up"]
        return cues.contains { lower.contains($0) }
    }
}
