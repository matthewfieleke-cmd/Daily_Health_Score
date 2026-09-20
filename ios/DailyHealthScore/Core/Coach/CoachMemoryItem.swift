import Foundation

/// The files the Coach keeps about a person. Every note lives in exactly one.
enum CoachMemorySection: String, CaseIterable, Identifiable, Codable, Sendable {
    case aboutYou
    case people
    case patterns
    case helps
    case goals
    case routines
    case body
    case checkIns

    var id: String { rawValue }

    var label: String {
        switch self {
        case .aboutYou: return "About you"
        case .people: return "People"
        case .patterns: return "Patterns & triggers"
        case .helps: return "What helps & what to avoid"
        case .goals: return "Goals & plans"
        case .routines: return "Routines & rhythms"
        case .body: return "Body & recovery"
        case .checkIns: return "Check-in notes"
        }
    }

    var systemImage: String {
        switch self {
        case .aboutYou: return "person.text.rectangle"
        case .people: return "person.2"
        case .patterns: return "waveform.path.ecg"
        case .helps: return "hand.thumbsup"
        case .goals: return "target"
        case .routines: return "clock.arrow.2.circlepath"
        case .body: return "figure.walk"
        case .checkIns: return "note.text"
        }
    }

    /// What belongs here, for the model.
    var promptHint: String {
        switch self {
        case .aboutYou: return "identity, values, how they like to be coached, what a good day looks like"
        case .people: return "partner, kids, friends, colleagues, and how those relationships affect health"
        case .patterns: return "eating or behavior triggers, stress load, what tends to go wrong and when"
        case .helps: return "what has worked before, what to avoid saying or suggesting"
        case .goals: return "what they are working toward and why, beyond the saved SMART goals"
        case .routines: return "work, sleep, meal, and movement rhythms; constraints like shift work or travel"
        case .body: return "injuries, recovery limits, conditions they named, energy patterns"
        case .checkIns: return "short dated notes from check-in replies: what they logged, how the day went"
        }
    }

    init(modelValue: String) {
        let text = modelValue.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        if let exact = CoachMemorySection.allCases.first(where: { $0.rawValue.lowercased() == text }) {
            self = exact
            return
        }
        if text.contains("people") || text.contains("relation") || text.contains("family") {
            self = .people
        } else if text.contains("pattern") || text.contains("trigger") || text.contains("stress") {
            self = .patterns
        } else if text.contains("help") || text.contains("avoid") {
            self = .helps
        } else if text.contains("goal") || text.contains("plan") {
            self = .goals
        } else if text.contains("routine") || text.contains("rhythm") || text.contains("schedule") {
            self = .routines
        } else if text.contains("body") || text.contains("recover") || text.contains("injur") || text.contains("health") {
            self = .body
        } else if text.contains("check") || text.contains("note") {
            self = .checkIns
        } else {
            self = .aboutYou
        }
    }
}

enum CoachMemoryCategory: String, CaseIterable, Identifiable, Codable, Sendable {
    // Current: one case per memory file.
    case aboutYou
    case people
    case patterns
    case helps
    case goals
    case routines
    case body
    case checkIns

    // Legacy narrow categories from earlier builds. Still readable, filed into a section.
    case preference
    case constraint
    case nutrition
    case movement
    case sleep
    case values
    case whatHelps
    case whatToAvoid
    case circumstance
    case goalContext
    case trigger
    case relationship
    case recovery
    case identity
    case stress
    case other

    var id: String { rawValue }

    init(section: CoachMemorySection) {
        switch section {
        case .aboutYou: self = .aboutYou
        case .people: self = .people
        case .patterns: self = .patterns
        case .helps: self = .helps
        case .goals: self = .goals
        case .routines: self = .routines
        case .body: self = .body
        case .checkIns: self = .checkIns
        }
    }

    var section: CoachMemorySection {
        switch self {
        case .aboutYou, .preference, .values, .identity, .circumstance, .other: return .aboutYou
        case .people, .relationship: return .people
        case .patterns, .trigger, .stress: return .patterns
        case .helps, .whatHelps, .whatToAvoid: return .helps
        case .goals, .goalContext: return .goals
        case .routines, .nutrition, .movement, .sleep, .constraint: return .routines
        case .body, .recovery: return .body
        case .checkIns: return .checkIns
        }
    }

    var label: String {
        switch self {
        case .aboutYou, .people, .patterns, .helps, .goals, .routines, .body, .checkIns:
            return section.label
        case .preference: return "Preference"
        case .constraint: return "Constraint"
        case .nutrition: return "Nutrition"
        case .movement: return "Movement"
        case .sleep: return "Sleep"
        case .values: return "Values"
        case .whatHelps: return "What helps"
        case .whatToAvoid: return "What to avoid"
        case .circumstance: return "Temporary circumstance"
        case .goalContext: return "Goal context"
        case .trigger: return "Trigger"
        case .relationship: return "Relationship"
        case .recovery: return "Recovery"
        case .identity: return "Identity"
        case .stress: return "Stress"
        case .other: return "Other"
        }
    }
}

enum CoachMemoryProvenance: String, Codable, Sendable {
    case userStated
    case userConfirmed
    case computedFromRecords
    /// Written by the Coach during a chat. Live unless the person edits or undoes it.
    case coachNoted
    /// Earlier builds: model guesses that were held apart from facts.
    case coachInterpretation
    case legacyCoachNotes

    var label: String {
        switch self {
        case .userStated: return "You said this"
        case .userConfirmed: return "You confirmed this"
        case .computedFromRecords: return "Computed from app records"
        case .coachNoted: return "Coach noted"
        case .coachInterpretation: return "Coach interpretation (unconfirmed)"
        case .legacyCoachNotes: return "Earlier coach note (unconfirmed)"
        }
    }

    var isConfirmedByUser: Bool {
        self == .userStated || self == .userConfirmed
    }

    /// Old-style guesses yield to a confirmed note in the same category.
    var yieldsToConfirmed: Bool {
        self == .coachInterpretation || self == .legacyCoachNotes
    }
}

enum CoachMemoryConfirmation: String, Codable, Sendable {
    case unconfirmed
    case confirmed
    case needsReview
    case expired
}

struct CoachMemoryItem: Identifiable, Equatable, Codable, Sendable {
    /// Notes ride along in every prompt, so each one stays short.
    static let maxContentLength = 160

    var id: UUID
    var category: CoachMemoryCategory
    var content: String
    var provenance: CoachMemoryProvenance
    var createdAt: Date
    var lastConfirmedAt: Date?
    var expiresAt: Date?
    var associatedGoalId: UUID?
    var confirmation: CoachMemoryConfirmation
    var isDeleted: Bool
    var contentFingerprint: String
    var supersededById: UUID?
    var sourceTurnId: UUID?
    var isTemporary: Bool

    init(
        id: UUID = UUID(),
        category: CoachMemoryCategory,
        content: String,
        provenance: CoachMemoryProvenance,
        createdAt: Date = Date(),
        lastConfirmedAt: Date? = nil,
        expiresAt: Date? = nil,
        associatedGoalId: UUID? = nil,
        confirmation: CoachMemoryConfirmation = .unconfirmed,
        isDeleted: Bool = false,
        contentFingerprint: String = "",
        supersededById: UUID? = nil,
        sourceTurnId: UUID? = nil,
        isTemporary: Bool = false
    ) {
        self.id = id
        self.category = category
        self.content = content
        self.provenance = provenance
        self.createdAt = createdAt
        self.lastConfirmedAt = lastConfirmedAt
        self.expiresAt = expiresAt
        self.associatedGoalId = associatedGoalId
        self.confirmation = confirmation
        self.isDeleted = isDeleted
        self.contentFingerprint = contentFingerprint.isEmpty
            ? CoachMemoryFingerprint.fingerprint(content)
            : contentFingerprint
        self.supersededById = supersededById
        self.sourceTurnId = sourceTurnId
        self.isTemporary = isTemporary
    }

    var section: CoachMemorySection { category.section }

    var displayContent: String {
        content.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func isEffective(at date: Date = Date()) -> Bool {
        if isDeleted { return false }
        if supersededById != nil { return false }
        if provenance == .computedFromRecords { return false }
        if confirmation == .expired { return false }
        if let expiresAt, expiresAt < date, confirmation != .confirmed {
            return false
        }
        return !displayContent.isEmpty
    }
}

/// One edit the Coach made to the files. Kept so the person can undo it.
enum CoachMemoryChangeKind: String, Codable, Sendable {
    case added
    case updated
    case removed
}

struct CoachMemoryChange: Identifiable, Equatable, Codable, Sendable {
    var id: UUID
    var kind: CoachMemoryChangeKind
    var section: CoachMemorySection
    /// The note this change produced (added or updated), or the note it removed.
    var itemId: UUID
    /// For updates: the note that was replaced.
    var previousItemId: UUID?
    var previousContent: String
    var newContent: String
    var createdAt: Date
    var threadId: UUID?
    var isUndone: Bool

    init(
        id: UUID = UUID(),
        kind: CoachMemoryChangeKind,
        section: CoachMemorySection,
        itemId: UUID,
        previousItemId: UUID? = nil,
        previousContent: String = "",
        newContent: String = "",
        createdAt: Date = Date(),
        threadId: UUID? = nil,
        isUndone: Bool = false
    ) {
        self.id = id
        self.kind = kind
        self.section = section
        self.itemId = itemId
        self.previousItemId = previousItemId
        self.previousContent = previousContent
        self.newContent = newContent
        self.createdAt = createdAt
        self.threadId = threadId
        self.isUndone = isUndone
    }

    var summaryLine: String {
        switch kind {
        case .added: return "Added: \(newContent)"
        case .updated: return "Updated: \(newContent)"
        case .removed: return "Removed: \(previousContent)"
        }
    }
}

/// A file edit the Coach asked for in a reply, already validated.
struct CoachMemoryUpdate: Equatable, Sendable {
    enum Operation: String, Sendable {
        case add
        case update
        case remove
    }

    var operation: Operation
    var section: CoachMemorySection
    var text: String
    var replaces: String

    init?(operation: String, section: String, text: String, replaces: String) {
        let op = operation.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let parsed: Operation
        if op.hasPrefix("add") || op.hasPrefix("creat") || op.hasPrefix("new") {
            parsed = .add
        } else if op.hasPrefix("upd") || op.hasPrefix("edit") || op.hasPrefix("chang") || op.hasPrefix("repl") {
            parsed = .update
        } else if op.hasPrefix("rem") || op.hasPrefix("del") || op.hasPrefix("forg") {
            parsed = .remove
        } else {
            return nil
        }
        let cleanText = CoachMemoryUpdate.cleaned(text)
        let cleanReplaces = CoachMemoryUpdate.cleaned(replaces)
        switch parsed {
        case .add:
            guard cleanText.count >= 4 else { return nil }
        case .update:
            guard cleanText.count >= 4 else { return nil }
        case .remove:
            guard cleanReplaces.count >= 4 || cleanText.count >= 4 else { return nil }
        }
        self.operation = parsed
        self.section = CoachMemorySection(modelValue: section)
        self.text = cleanText
        self.replaces = cleanReplaces.isEmpty && parsed == .remove ? cleanText : cleanReplaces
    }

    init(operation: Operation, section: CoachMemorySection, text: String, replaces: String = "") {
        self.operation = operation
        self.section = section
        self.text = CoachMemoryUpdate.cleaned(text)
        self.replaces = CoachMemoryUpdate.cleaned(replaces)
    }

    static func cleaned(_ text: String) -> String {
        let flat = text
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "**", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let collapsed = flat.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
        guard collapsed.count > CoachMemoryItem.maxContentLength else { return collapsed }
        let cut = String(collapsed.prefix(CoachMemoryItem.maxContentLength))
        if let space = cut.lastIndex(of: " ") {
            return String(cut[..<space])
        }
        return cut
    }
}

enum CoachMemoryFingerprint {
    static func fingerprint(_ content: String) -> String {
        let normalized = normalize(content)
        var hash: UInt64 = 5381
        for byte in normalized.utf8 {
            hash = hash &* 33 &+ UInt64(byte)
        }
        return String(hash, radix: 16)
    }

    static func normalize(_ content: String) -> String {
        content
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
    }

    static func looksTemporary(_ content: String) -> Bool {
        let text = content.lowercased()
        let cues = [
            "travel", "traveling", "travelling", "vacation", "holiday",
            "visiting", "this week", "for a few days", "injured", "injury",
            "sprain", "sprained", "short-term", "temporarily", "jet lag"
        ]
        return cues.contains { text.contains($0) }
    }
}

enum CoachMemoryLogic {
    static func effectiveItems(_ items: [CoachMemoryItem], at date: Date = Date()) -> [CoachMemoryItem] {
        items
            .filter { $0.isEffective(at: date) }
            .sorted { $0.createdAt > $1.createdAt }
    }

    static func isTombstoned(content: String, tombstones: Set<String>) -> Bool {
        tombstones.contains(CoachMemoryFingerprint.fingerprint(content))
    }

    /// Old-style model guesses drop out once the person has confirmed a note in
    /// the same category. Coach-noted files stay; the person edits them directly.
    static func itemsByOverridingContradictions(_ items: [CoachMemoryItem], at date: Date = Date()) -> [CoachMemoryItem] {
        let live = effectiveItems(items, at: date)
        return live.filter { item in
            guard item.provenance.yieldsToConfirmed else { return true }
            let overridden = live.contains { existing in
                existing.category == item.category
                    && existing.provenance.isConfirmedByUser
                    && existing.id != item.id
            }
            return !overridden
        }
    }

    /// The files as the model sees them: every live note, grouped by file.
    static func promptBlock(
        items: [CoachMemoryItem],
        tombstonesIgnored: Bool = true,
        at date: Date = Date(),
        perSectionLimit: Int = 10
    ) -> String {
        let live = itemsByOverridingContradictions(items, at: date)
        if live.isEmpty { return "No notes yet. Write down what a careful coach would keep." }
        var parts: [String] = []
        for section in CoachMemorySection.allCases {
            let rows = live.filter { $0.section == section }
            guard !rows.isEmpty else { continue }
            let lines = rows.prefix(perSectionLimit).map { item -> String in
                let marker = item.provenance.isConfirmedByUser ? " (they said this)" : ""
                return "- \(item.displayContent)\(marker)"
            }
            parts.append("\(section.label.uppercased()):\n" + lines.joined(separator: "\n"))
        }
        let awaiting = items.filter {
            !$0.isDeleted && $0.isTemporary && ($0.confirmation == .needsReview || ($0.expiresAt ?? .distantFuture) < date)
        }
        if !awaiting.isEmpty {
            parts.append("Temporary notes may have lapsed; ask before treating them as current.")
        }
        _ = tombstonesIgnored
        return parts.joined(separator: "\n")
    }

    /// Finds the note a model update refers to. Exact text first, then containment,
    /// then word overlap, preferring the named section.
    static func match(
        _ reference: String,
        in items: [CoachMemoryItem],
        section: CoachMemorySection?,
        at date: Date = Date()
    ) -> CoachMemoryItem? {
        let needle = CoachMemoryFingerprint.normalize(reference)
        guard needle.count >= 4 else { return nil }
        let live = effectiveItems(items, at: date)
        let ordered = live.sorted { lhs, rhs in
            let lhsSame = lhs.section == section
            let rhsSame = rhs.section == section
            if lhsSame != rhsSame { return lhsSame }
            return lhs.createdAt > rhs.createdAt
        }
        if let exact = ordered.first(where: { CoachMemoryFingerprint.normalize($0.content) == needle }) {
            return exact
        }
        if needle.count >= 12 {
            if let contained = ordered.first(where: {
                let hay = CoachMemoryFingerprint.normalize($0.content)
                return hay.contains(needle) || needle.contains(hay)
            }) {
                return contained
            }
        }
        // Overlap coefficient: shared words over the shorter note, so a short
        // reference still finds a longer note it paraphrases.
        let needleWords = significantWords(needle)
        guard needleWords.count >= 2 else { return nil }
        var best: (item: CoachMemoryItem, score: Double)?
        for item in ordered {
            let words = significantWords(CoachMemoryFingerprint.normalize(item.content))
            guard !words.isEmpty else { continue }
            let overlap = needleWords.intersection(words).count
            guard overlap >= 2 else { continue }
            let score = Double(overlap) / Double(min(needleWords.count, words.count))
            if score >= 0.6, score > (best?.score ?? 0) {
                best = (item, score)
            }
        }
        return best?.item
    }

    /// True when an equivalent note already exists, so an add is a no-op.
    static func hasEquivalent(_ text: String, in items: [CoachMemoryItem], at date: Date = Date()) -> Bool {
        let needle = CoachMemoryFingerprint.normalize(text)
        guard !needle.isEmpty else { return true }
        for item in effectiveItems(items, at: date) {
            let hay = CoachMemoryFingerprint.normalize(item.content)
            if hay == needle { return true }
            if needle.count >= 16, hay.count >= 16, hay.contains(needle) || needle.contains(hay) { return true }
        }
        return false
    }

    static func significantWords(_ normalized: String) -> Set<String> {
        let stop: Set<String> = [
            "the", "a", "an", "and", "or", "to", "of", "in", "on", "at", "for", "with",
            "is", "are", "was", "were", "be", "they", "their", "them", "he", "she", "his",
            "her", "it", "its", "that", "this", "when", "after", "before", "has", "have",
            "had", "not", "no", "do", "does", "did", "but", "so", "as", "by", "from"
        ]
        let words = normalized
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.count >= 3 && !stop.contains($0) }
        return Set(words)
    }

    static func profile(from items: [CoachMemoryItem], at date: Date = Date()) -> CoachUserProfile {
        var profile = CoachUserProfile()
        func join(_ category: CoachMemoryCategory) -> String {
            itemsByOverridingContradictions(items, at: date)
                .filter { $0.category == category }
                .map(\.displayContent)
                .joined(separator: "; ")
        }
        profile.preferredStyle = join(.preference)
        profile.constraints = join(.constraint)
        profile.nutritionNotes = join(.nutrition)
        profile.movementNotes = join(.movement)
        profile.sleepNotes = join(.sleep)
        profile.values = join(.values)
        profile.whatHelps = join(.whatHelps)
        profile.whatToAvoid = join(.whatToAvoid)
        profile.triggers = join(.trigger)
        profile.relationships = join(.relationship)
        profile.recoveryNotes = join(.recovery)
        profile.identityNotes = join(.identity)
        profile.stressNotes = join(.stress)
        return profile
    }

    static func legacyItems(from profile: CoachUserProfile, recordedAt: Date) -> [CoachMemoryItem] {
        func item(_ category: CoachMemoryCategory, _ value: String) -> CoachMemoryItem? {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return nil }
            let temporary = CoachMemoryFingerprint.looksTemporary(trimmed)
            return CoachMemoryItem(
                category: category,
                content: trimmed,
                provenance: .legacyCoachNotes,
                createdAt: recordedAt,
                expiresAt: temporary ? recordedAt.addingTimeInterval(14 * 86_400) : nil,
                confirmation: temporary ? .needsReview : .unconfirmed,
                isTemporary: temporary
            )
        }
        return [
            item(.preference, profile.preferredStyle),
            item(.constraint, profile.constraints),
            item(.nutrition, profile.nutritionNotes),
            item(.movement, profile.movementNotes),
            item(.sleep, profile.sleepNotes),
            item(.values, profile.values),
            item(.whatHelps, profile.whatHelps),
            item(.whatToAvoid, profile.whatToAvoid),
            item(.trigger, profile.triggers),
            item(.relationship, profile.relationships),
            item(.recovery, profile.recoveryNotes),
            item(.identity, profile.identityNotes),
            item(.stress, profile.stressNotes)
        ].compactMap { $0 }
    }

    static func interpretationItems(from profile: CoachUserProfile, recordedAt: Date) -> [CoachMemoryItem] {
        func item(_ category: CoachMemoryCategory, _ value: String) -> CoachMemoryItem? {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return nil }
            let temporary = CoachMemoryFingerprint.looksTemporary(trimmed)
            return CoachMemoryItem(
                category: category,
                content: String(trimmed.prefix(CoachUserProfile.maxFieldLength)),
                provenance: .coachInterpretation,
                createdAt: recordedAt,
                expiresAt: temporary ? recordedAt.addingTimeInterval(14 * 86_400) : nil,
                confirmation: .needsReview,
                isTemporary: temporary || category == .circumstance
            )
        }
        return [
            item(.preference, profile.preferredStyle),
            item(.constraint, profile.constraints),
            item(.nutrition, profile.nutritionNotes),
            item(.movement, profile.movementNotes),
            item(.sleep, profile.sleepNotes),
            item(.values, profile.values),
            item(.whatHelps, profile.whatHelps),
            item(.whatToAvoid, profile.whatToAvoid),
            item(.trigger, profile.triggers),
            item(.relationship, profile.relationships),
            item(.recovery, profile.recoveryNotes),
            item(.identity, profile.identityNotes),
            item(.stress, profile.stressNotes)
        ].compactMap { $0 }
    }

    static func sanitizeSummary(_ summary: String, removing contents: [String]) -> String {
        guard !summary.isEmpty else { return summary }
        var sentences = summary.components(separatedBy: CharacterSet(charactersIn: ".!?"))
        sentences = sentences.filter { sentence in
            let trimmed = sentence.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return false }
            return !contents.contains { fact in
                let needle = fact.trimmingCharacters(in: .whitespacesAndNewlines)
                return !needle.isEmpty && trimmed.localizedCaseInsensitiveContains(needle)
            }
        }
        return sentences
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: ". ")
    }
}
