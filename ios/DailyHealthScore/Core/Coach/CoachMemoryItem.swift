import Foundation

/// The files the Coach keeps about a person. Every note lives in exactly one.
/// Raw values are storage keys; two keep their build-20 spelling on purpose.
enum CoachMemorySection: String, CaseIterable, Identifiable, Codable, Sendable {
    case aboutYou
    case people
    case patterns
    case coaching = "helps"
    case goals
    case likes
    case routines
    case body
    case recent = "checkIns"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .aboutYou: return "About you"
        case .people: return "People"
        case .patterns: return "Patterns & triggers"
        case .coaching: return "How to coach me"
        case .goals: return "Goals & plans"
        case .likes: return "Likes & staples"
        case .routines: return "Routines & rhythms"
        case .body: return "Body & health"
        case .recent: return "Recent"
        }
    }

    /// The name the model uses when it files a note.
    var modelKey: String {
        switch self {
        case .coaching: return "coaching"
        case .recent: return "recent"
        default: return rawValue
        }
    }

    var systemImage: String {
        switch self {
        case .aboutYou: return "person.text.rectangle"
        case .people: return "person.2"
        case .patterns: return "waveform.path.ecg"
        case .coaching: return "text.bubble"
        case .goals: return "target"
        case .likes: return "heart.text.square"
        case .routines: return "clock.arrow.2.circlepath"
        case .body: return "figure.walk"
        case .recent: return "clock"
        }
    }

    /// What belongs here, for the model. One fact has one home.
    var promptHint: String {
        switch self {
        case .aboutYou: return "name, work, and values, in their words. Not the weekly schedule"
        case .people: return "who is in their life: names, ages, and the relationship. Not the pattern those people are part of"
        case .patterns: return "one fact about what happens under strain. Not a schedule, and not several facts packed together"
        case .coaching: return "how they want to be coached: what lands, what to avoid, what to call them"
        case .goals: return "direction they are working toward that is not already a saved SMART goal"
        case .likes: return "named foods, products, and activities they enjoy"
        case .routines: return "the weekly clock: work days, sleep, meal timing, commute"
        case .body: return "conditions, medicines, injuries, and limits, as they said them. Not the score"
        case .recent: return "dated state that will go stale: mood, the current hurdle, a recent change"
        }
    }

    /// Whether an entry here describes a passing state rather than a durable fact.
    var isStateFile: Bool { self == .recent }

    init(modelValue: String) {
        let text = modelValue.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        if let exact = CoachMemorySection.allCases.first(where: {
            $0.rawValue.lowercased() == text || $0.modelKey.lowercased() == text
        }) {
            self = exact
            return
        }
        if text.contains("people") || text.contains("relation") || text.contains("family") {
            self = .people
        } else if text.contains("pattern") || text.contains("trigger") {
            self = .patterns
        } else if text.contains("coach") || text.contains("prefer") || text.contains("help") || text.contains("avoid") {
            self = .coaching
        } else if text.contains("goal") || text.contains("plan") || text.contains("motto") {
            self = .goals
        } else if text.contains("like") || text.contains("staple") || text.contains("food") || text.contains("enjoy") {
            self = .likes
        } else if text.contains("routine") || text.contains("rhythm") || text.contains("schedule") || text.contains("work") {
            self = .routines
        } else if text.contains("body") || text.contains("recover") || text.contains("injur") || text.contains("health") || text.contains("weight") {
            self = .body
        } else if text.contains("recent") || text.contains("check") || text.contains("mood") || text.contains("hurdle") || text.contains("now") || text.contains("state") {
            self = .recent
        } else if text.contains("stress") {
            self = .patterns
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
    case likes
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
        case .coaching: self = .helps
        case .goals: self = .goals
        case .likes: self = .likes
        case .routines: self = .routines
        case .body: self = .body
        case .recent: self = .checkIns
        }
    }

    var section: CoachMemorySection {
        switch self {
        case .aboutYou, .values, .identity, .other: return .aboutYou
        case .people, .relationship: return .people
        case .patterns, .trigger, .stress: return .patterns
        case .helps, .whatHelps, .whatToAvoid, .preference: return .coaching
        case .goals, .goalContext: return .goals
        case .likes: return .likes
        case .routines, .nutrition, .movement, .sleep, .constraint: return .routines
        case .body, .recovery: return .body
        case .checkIns, .circumstance: return .recent
        }
    }

    var label: String {
        switch self {
        case .aboutYou, .people, .patterns, .helps, .goals, .likes, .routines, .body, .checkIns:
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
    /// The Coach wrote down something the person said. A stated fact.
    case coachRecorded
    /// The Coach's own read of the person. Inferred until they confirm it.
    case coachNoted
    /// Earlier builds: model guesses that were held apart from facts.
    case coachInterpretation
    case legacyCoachNotes

    var label: String {
        switch self {
        case .userStated: return "You said this"
        case .userConfirmed: return "You confirmed this"
        case .computedFromRecords: return "Computed from app records"
        case .coachRecorded: return "You told your coach"
        case .coachNoted: return "Your coach's read — tap Confirm if it fits"
        case .coachInterpretation: return "Coach interpretation (unconfirmed)"
        case .legacyCoachNotes: return "Earlier coach note (unconfirmed)"
        }
    }

    var isConfirmedByUser: Bool {
        self == .userStated || self == .userConfirmed
    }

    /// Whether the note records what the person said rather than a guess.
    var isStated: Bool {
        isConfirmedByUser || self == .coachRecorded
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
    /// One idea per note. Long enough for a pattern with its trigger and antidote.
    static let maxContentLength = 240

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
    /// Same note, different file. Undo moves it back.
    case refiled
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
        case .refiled: return "Moved to \(section.label): \(newContent)"
        }
    }
}

/// A file edit the Coach asked for in a reply, already validated.
struct CoachMemoryUpdate: Equatable, Sendable {
    enum Operation: String, Sendable {
        case add
        case update
        case merge
        case refile
        case remove
    }

    /// Whether the note records what the person said or the Coach's read of them.
    enum Basis: String, Sendable {
        case stated
        case inferred

        init(modelValue: String) {
            let text = modelValue.lowercased()
            self = text.hasPrefix("infer") || text.hasPrefix("guess") || text.hasPrefix("read") ? .inferred : .stated
        }

        var provenance: CoachMemoryProvenance {
            self == .stated ? .coachRecorded : .coachNoted
        }
    }

    var operation: Operation
    var section: CoachMemorySection
    var text: String
    var replaces: String
    /// The second note a merge folds in.
    var alsoReplaces: String
    var basis: Basis = .stated

    init?(operation: String, section: String, text: String, replaces: String, alsoReplaces: String = "", basis: String = "stated") {
        let op = operation.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let parsed: Operation
        if op.hasPrefix("add") || op.hasPrefix("creat") || op.hasPrefix("new") {
            parsed = .add
        } else if op.hasPrefix("merg") || op.hasPrefix("combin") || op.hasPrefix("fold") {
            parsed = .merge
        } else if op.hasPrefix("refile") || op.hasPrefix("move") {
            parsed = .refile
        } else if op.hasPrefix("upd") || op.hasPrefix("edit") || op.hasPrefix("chang") || op.hasPrefix("repl") {
            parsed = .update
        } else if op.hasPrefix("rem") || op.hasPrefix("del") || op.hasPrefix("forg") || op.hasPrefix("retir") {
            parsed = .remove
        } else {
            return nil
        }
        let cleanText = CoachMemoryUpdate.cleaned(text)
        let cleanReplaces = CoachMemoryUpdate.cleaned(replaces)
        let cleanAlso = CoachMemoryUpdate.cleaned(alsoReplaces)
        switch parsed {
        case .add, .update:
            guard cleanText.count >= 4 else { return nil }
        case .merge:
            guard cleanText.count >= 4, cleanReplaces.count >= 4, cleanAlso.count >= 4 else { return nil }
        case .refile, .remove:
            guard cleanReplaces.count >= 4 || cleanText.count >= 4 else { return nil }
        }
        self.operation = parsed
        self.section = CoachMemorySection(modelValue: section)
        self.text = cleanText
        self.replaces = cleanReplaces.isEmpty && (parsed == .remove || parsed == .refile) ? cleanText : cleanReplaces
        self.alsoReplaces = cleanAlso
        self.basis = Basis(modelValue: basis)
    }

    init(operation: Operation, section: CoachMemorySection, text: String, replaces: String = "", alsoReplaces: String = "", basis: Basis = .stated) {
        self.operation = operation
        self.section = section
        self.text = CoachMemoryUpdate.cleaned(text)
        self.replaces = CoachMemoryUpdate.cleaned(replaces)
        self.alsoReplaces = CoachMemoryUpdate.cleaned(alsoReplaces)
        self.basis = basis
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

/// One housekeeping edit proposed by the files review pass, already validated.
struct CoachFileReviewOperation: Equatable, Sendable {
    enum Kind: String, Sendable {
        case refile
        case update
        case retire
        case add
    }

    var kind: Kind
    /// First eight characters of the entry id, as listed to the model. Empty for add.
    var idPrefix: String
    var section: CoachMemorySection?
    var text: String
    var basis: CoachMemoryUpdate.Basis

    init?(kind: String, id: String, section: String, text: String, basis: String) {
        let op = kind.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let parsed: Kind
        if op.hasPrefix("refile") || op.hasPrefix("move") {
            parsed = .refile
        } else if op.hasPrefix("upd") || op.hasPrefix("rewrite") || op.hasPrefix("edit") {
            parsed = .update
        } else if op.hasPrefix("retire") || op.hasPrefix("rem") || op.hasPrefix("del") || op.hasPrefix("stale") {
            parsed = .retire
        } else if op.hasPrefix("add") || op.hasPrefix("promote") || op.hasPrefix("new") {
            parsed = .add
        } else {
            return nil
        }
        let prefix = String(id.trimmingCharacters(in: .whitespacesAndNewlines).prefix(8)).lowercased()
        let cleanText = CoachMemoryUpdate.cleaned(text)
        let trimmedSection = section.trimmingCharacters(in: .whitespacesAndNewlines)
        switch parsed {
        case .refile:
            guard prefix.count == 8, !trimmedSection.isEmpty else { return nil }
        case .update:
            guard prefix.count == 8, cleanText.count >= 4 else { return nil }
        case .retire:
            guard prefix.count == 8 else { return nil }
        case .add:
            guard cleanText.count >= 4, !trimmedSection.isEmpty else { return nil }
        }
        self.kind = parsed
        self.idPrefix = prefix
        self.section = trimmedSection.isEmpty ? nil : CoachMemorySection(modelValue: trimmedSection)
        self.text = cleanText
        self.basis = CoachMemoryUpdate.Basis(modelValue: basis)
    }
}

enum CoachMemoryFingerprint {
    struct ProfileSourceEntry: Equatable, Sendable {
        var id: String
        var section: String
        var stated: Bool
        var content: String
    }

    /// The picture a compiled background was written from. A new day, a
    /// confirmation, or an edited note changes it, so yesterday's paragraph
    /// is not served as today's.
    static func profileSource(generation: String, day: String, entries: [ProfileSourceEntry]) -> String {
        let lines = entries.map { entry in
            "\(entry.id)|\(entry.section)|\(entry.stated ? "stated" : "inferred")|\(entry.content)"
        }
        return ([generation, day] + lines).joined(separator: "\n")
    }

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

    /// Words that carry a note's substance: long enough to mean something and
    /// not scaffolding. Names and numbers count.
    static func substanceWords(in text: String) -> Set<String> {
        let stop: Set<String> = [
            "about", "after", "again", "also", "always", "another", "around", "because", "been", "before",
            "being", "between", "both", "could", "does", "doing", "during", "each", "either", "every",
            "feels", "from", "have", "having", "help", "helps", "helpful", "into", "just", "keeps", "like",
            "likely", "makes", "many", "more", "most", "much", "often", "only", "other", "over", "part",
            "person", "really", "same", "says", "seems", "since", "some", "something", "still", "such",
            "than", "that", "their", "them", "then", "there", "these", "they", "thing", "things", "this",
            "those", "through", "under", "until", "uses", "very", "want", "wants", "when", "where",
            "which", "while", "will", "with", "within", "without", "would", "your", "stated", "inferred",
            "january", "february", "march", "april", "june", "july", "august", "september", "october",
            "november", "december", "2025", "2026", "2027", "tends", "tend", "usually", "sometimes"
        ]
        let tokens = text.lowercased()
            .replacingOccurrences(of: "’", with: "'")
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.count >= 4 || ($0.count >= 2 && $0.allSatisfy(\.isNumber)) }
        return Set(tokens.filter { !stop.contains($0) }.map { $0.hasSuffix("s") && $0.count > 4 ? String($0.dropLast()) : $0 })
    }

    /// A new note has to come from the person's words. The Coach's own
    /// suggestions filed as facts about the person are how a memory drifts from
    /// the truth; this keeps them out. A rewrite may reuse the notes it
    /// replaces, and may not introduce a substance word from anywhere else.
    static func isGrounded(
        _ update: CoachMemoryUpdate,
        inPersonsWords words: String,
        retaining existingNotes: [String] = []
    ) -> Bool {
        if update.operation == .remove || update.operation == .refile { return true }
        let noteWords = substanceWords(in: update.text)
        guard !noteWords.isEmpty else { return false }
        if update.operation == .update || update.operation == .merge {
            let allowed = substanceWords(in: ([words] + existingNotes).joined(separator: " "))
            return noteWords.isSubset(of: allowed)
        }
        let spoken = substanceWords(in: words)
        let overlap = noteWords.intersection(spoken).count
        return noteWords.count <= 4 ? overlap >= 1 : overlap >= 2
    }

    /// Notes relevant to the subject the Coach asked about. A tool query should
    /// narrow what comes back; returning the whole biography would make the
    /// query another dummy argument and invite unrelated callbacks.
    static func items(
        relevantTo topic: String,
        in items: [CoachMemoryItem],
        at date: Date = Date(),
        limit: Int = 12
    ) -> [CoachMemoryItem] {
        let query = topic.trimmingCharacters(in: .whitespacesAndNewlines)
        let queryWords = substanceWords(in: query)
        guard !queryWords.isEmpty, limit > 0 else { return [] }

        let normalized = query.lowercased()
        let broad = ["everything", "whole profile", "full profile", "all notes", "background"]
            .contains { normalized.contains($0) }
        let live = itemsByOverridingContradictions(items, at: date)
        if broad { return Array(live.prefix(limit)) }

        let direct: [(item: CoachMemoryItem, score: Int)] = live.compactMap { item in
            let content = item.displayContent.lowercased()
            let exactPhrase = content.contains(normalized) ? 8 : 0
            let contentOverlap = substanceWords(in: content).intersection(queryWords).count
            let score = exactPhrase + contentOverlap * 4
            return score > 0 ? (item, score) : nil
        }
        let scored: [(item: CoachMemoryItem, score: Int)]
        if !direct.isEmpty {
            scored = direct
        } else {
            // A section hint is a fallback, never a reason to append an entire
            // file after direct matches already answered the query.
            scored = live.compactMap { item in
                let sectionWords = substanceWords(
                    in: "\(item.section.label) \(item.section.modelKey) \(item.section.promptHint)"
                )
                let score = sectionWords.intersection(queryWords).count
                return score > 0 ? (item, score) : nil
            }
        }
        return scored
            .sorted {
                $0.score == $1.score
                    ? $0.item.createdAt > $1.item.createdAt
                    : $0.score > $1.score
            }
            .prefix(limit)
            .map { $0.item }
    }

    static func promptBlock(
        items: [CoachMemoryItem],
        relevantTo topic: String,
        at date: Date = Date(),
        limit: Int = 12,
        calendar: Calendar = .current
    ) -> String {
        let relevant = self.items(relevantTo: topic, in: items, at: date, limit: limit)
        guard !relevant.isEmpty else {
            return "No saved notes match this topic."
        }
        return promptBlock(
            items: relevant,
            at: date,
            perSectionLimit: limit,
            calendar: calendar
        )
    }

    /// Matching notes for a tool result. Sentences only: file headings turn
    /// the list into an assignment.
    static func matchingNotes(
        items: [CoachMemoryItem],
        relevantTo topic: String,
        at date: Date = Date(),
        limit: Int = 6,
        calendar: Calendar = .current
    ) -> String {
        let relevant = self.items(relevantTo: topic, in: items, at: date, limit: limit)
        guard !relevant.isEmpty else {
            return "No saved notes match this topic."
        }
        return relevant.map { item in
            var line = "\(entryDate(item.createdAt, now: date, calendar: calendar)): \(item.displayContent)"
            if item.provenance.isStated {
                line += " (stated)"
            } else if item.provenance == .coachNoted || item.provenance.yieldsToConfirmed {
                line += " (inferred)"
            }
            if item.section.isStateFile,
               let days = calendar.dateComponents([.day], from: item.createdAt, to: date).day,
               days > recentWindowDays {
                line += " (older)"
            }
            return line
        }.joined(separator: "\n")
    }

    /// A handful of dated notes for the Home card. Newest first, no file
    /// headings: the card uses a note only when it changes a thought, and a
    /// heading would turn the list into an assignment.
    static func cardNotes(
        items: [CoachMemoryItem],
        at date: Date = Date(),
        limit: Int = 6,
        calendar: Calendar = .current
    ) -> String {
        let live = itemsByOverridingContradictions(items, at: date)
            .sorted { $0.createdAt > $1.createdAt }
        guard !live.isEmpty else { return "No saved notes." }
        return live.prefix(limit).map { item in
            var line = "\(entryDate(item.createdAt, now: date, calendar: calendar)): \(item.displayContent)"
            if item.provenance.isStated {
                line += " (stated)"
            } else if item.provenance == .coachNoted || item.provenance.yieldsToConfirmed {
                line += " (inferred)"
            }
            if item.section.isStateFile,
               let days = calendar.dateComponents([.day], from: item.createdAt, to: date).day,
               days > recentWindowDays {
                line += " (older)"
            }
            return line
        }.joined(separator: "\n")
    }

    /// The durable files with nothing in them yet, in the order the intake
    /// asks about them. Recent is state, not a file to fill.
    static func emptySections(in items: [CoachMemoryItem]) -> [CoachMemorySection] {
        let filled = Set(items.map(\.section))
        let intakeOrder: [CoachMemorySection] = [
            .aboutYou, .routines, .people, .likes, .body, .patterns, .coaching, .goals
        ]
        return intakeOrder.filter { !filled.contains($0) }
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

    /// State entries older than this are background, not the present.
    static let recentWindowDays = 21

    /// The files as the model sees them: every live note, dated, grouped by
    /// file, with what the person said kept apart from what the Coach inferred.
    static func promptBlock(
        items: [CoachMemoryItem],
        tombstonesIgnored: Bool = true,
        at date: Date = Date(),
        perSectionLimit: Int = 12,
        calendar: Calendar = .current,
        sections: Set<CoachMemorySection>? = nil
    ) -> String {
        let live = itemsByOverridingContradictions(items, at: date)
            .filter { sections?.contains($0.section) ?? true }
        if live.isEmpty {
            return sections == nil
                ? "No notes yet. Write down what a careful coach would keep."
                : "No notes in these files yet."
        }
        var parts: [String] = []
        for section in CoachMemorySection.allCases where sections?.contains(section) ?? true {
            let rows = live.filter { $0.section == section }
            guard !rows.isEmpty else { continue }
            let ordered = rows.sorted { $0.createdAt > $1.createdAt }
            let lines = ordered.prefix(perSectionLimit).map { item -> String in
                var line = "- [\(entryDate(item.createdAt, now: date, calendar: calendar))] \(item.displayContent)"
                if item.provenance.isStated {
                    line += " (stated)"
                } else if item.provenance == .coachNoted || item.provenance.yieldsToConfirmed {
                    line += " (inferred)"
                }
                if section.isStateFile,
                   let days = calendar.dateComponents([.day], from: item.createdAt, to: date).day,
                   days > recentWindowDays {
                    line += " (older)"
                }
                return line
            }
            let header = section.isStateFile
                ? "\(section.label.uppercased()) (newest first; entries marked older are background):"
                : "\(section.label.uppercased()):"
            parts.append(header + "\n" + lines.joined(separator: "\n"))
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

    /// "Sep 20" this year, "Sep 20, 2025" otherwise. Model-facing, so the
    /// format is fixed rather than following the device locale.
    static func entryDate(_ date: Date, now: Date = Date(), calendar: Calendar = .current) -> String {
        let sameYear = calendar.component(.year, from: date) == calendar.component(.year, from: now)
        var style = Date.FormatStyle(locale: Locale(identifier: "en_US"), calendar: calendar, timeZone: calendar.timeZone)
        style = sameYear ? style.month(.abbreviated).day() : style.month(.abbreviated).day().year()
        return date.formatted(style)
    }

    /// A date the compiler can compare with each note's date, year included.
    static func compilerToday(_ date: Date = Date(), calendar: Calendar = .current) -> String {
        var style = Date.FormatStyle(locale: Locale(identifier: "en_US"), calendar: calendar, timeZone: calendar.timeZone)
        style = style.weekday(.abbreviated).month(.abbreviated).day().year()
        return date.formatted(style)
    }

    static func entryLine(for item: CoachMemoryItem, at date: Date, calendar: Calendar) -> String {
        let stated = item.provenance.isStated ? "stated" : "inferred"
        return "\(item.id.uuidString.prefix(8)) | \(item.section.modelKey) | \(entryDate(item.createdAt, now: date, calendar: calendar)) | \(stated) | \(item.displayContent)"
    }

    /// Entries as a compact list for the on-device filing and review passes.
    static func entryList(items: [CoachMemoryItem], at date: Date = Date(), calendar: Calendar = .current) -> String {
        let live = itemsByOverridingContradictions(items, at: date).sorted { $0.createdAt > $1.createdAt }
        if live.isEmpty { return "None." }
        return live.map { entryLine(for: $0, at: date, calendar: calendar) }.joined(separator: "\n")
    }

    /// Notes for the background compiler. One newest note from each file,
    /// then the next, so a long Recent file cannot push a durable fact out
    /// of the window. Whole lines only.
    static func compilerEntryList(
        items: [CoachMemoryItem],
        at date: Date = Date(),
        calendar: Calendar = .current,
        characterBudget: Int = 9_000
    ) -> String {
        let live = itemsByOverridingContradictions(items, at: date)
        guard !live.isEmpty, characterBudget > 0 else { return "None." }
        let grouped = CoachMemorySection.allCases.map { section in
            live.filter { $0.section == section }.sorted { $0.createdAt > $1.createdAt }
        }
        var cursors = Array(repeating: 0, count: grouped.count)
        var lines: [String] = []
        var used = 0
        var progressed = true
        while progressed {
            progressed = false
            for index in grouped.indices {
                guard cursors[index] < grouped[index].count else { continue }
                let line = entryLine(for: grouped[index][cursors[index]], at: date, calendar: calendar)
                let cost = line.count + (lines.isEmpty ? 0 : 1)
                if used + cost > characterBudget {
                    cursors[index] = grouped[index].count
                    continue
                }
                lines.append(line)
                used += cost
                cursors[index] += 1
                progressed = true
            }
        }
        return lines.isEmpty ? "None." : lines.joined(separator: "\n")
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

    /// True when a note already on file is at least as specific, so an add is a no-op.
    static func hasEquivalent(_ text: String, in items: [CoachMemoryItem], at date: Date = Date()) -> Bool {
        coveringNote(for: text, in: items, at: date) != nil
    }

    /// How one proposed note should land among the notes already on file.
    /// A newer wording never replaces a more specific one.
    enum Filing: Equatable {
        case store(section: CoachMemorySection, retiring: [UUID])
        case refile(id: UUID, section: CoachMemorySection)
        case remove(id: UUID)
        case alreadyKept(String)
        case reject(String)
    }

    static func filing(
        for update: CoachMemoryUpdate,
        in items: [CoachMemoryItem],
        at date: Date = Date(),
        keepExistingSection: Bool
    ) -> Filing {
        let live = effectiveItems(items, at: date)
        switch update.operation {
        case .add:
            if let kept = coveringNote(for: update.text, in: live, at: date) {
                return .alreadyKept(kept.content)
            }
            let weaker = lessSpecificNotes(than: update.text, in: live, at: date)
                .sorted { isPreferable($0, to: $1) }
            let section: CoachMemorySection
            if keepExistingSection, let richest = weaker.first {
                section = richest.section
            } else {
                section = update.section
            }
            return .store(section: section, retiring: weaker.map(\.id))
        case .update:
            let reference = update.replaces.isEmpty ? update.text : update.replaces
            guard let target = match(reference, in: live, section: update.section, at: date) else {
                return .reject("Not kept: no note matched. Quote the existing note.")
            }
            if losesSpecifics(from: [target.content], replacement: update.text) {
                return .reject("Not kept: that would drop a specific already on file.")
            }
            if !isStricter(update.text, than: target.content), !contradicts(update.text, target.content) {
                return .alreadyKept(target.content)
            }
            let extras = lessSpecificNotes(than: update.text, in: live, at: date).filter { $0.id != target.id }
            return .store(section: target.section, retiring: [target.id] + extras.map(\.id))
        case .merge:
            guard let first = match(update.replaces, in: live, section: nil, at: date),
                  let second = match(update.alsoReplaces, in: live, section: nil, at: date),
                  first.id != second.id else {
                return .reject("Not kept: no note matched. Quote both existing notes.")
            }
            if losesSpecifics(from: [first.content, second.content], replacement: update.text) {
                return .reject("Not kept: that would drop a specific already on file.")
            }
            let richer = isPreferable(first, to: second) ? first : second
            let poorer = richer.id == first.id ? second : first
            if !isStricter(update.text, than: richer.content),
               covers(richer.content, update.text),
               covers(richer.content, poorer.content) {
                return .remove(id: poorer.id)
            }
            let section = (update.section == first.section || update.section == second.section)
                ? update.section
                : richer.section
            let ordered = [richer, poorer].sorted { isPreferable($0, to: $1) }
            return .store(section: section, retiring: ordered.map(\.id))
        case .refile:
            let reference = update.replaces.isEmpty ? update.text : update.replaces
            guard let target = match(reference, in: live, section: nil, at: date) else {
                return .reject("Not kept: no note matched. Quote the existing note.")
            }
            if target.section == update.section { return .alreadyKept(target.content) }
            return .refile(id: target.id, section: update.section)
        case .remove:
            let reference = update.replaces.isEmpty ? update.text : update.replaces
            guard let target = match(reference, in: live, section: update.section, at: date) else {
                return .reject("Not kept: no note matched. Quote the existing note.")
            }
            return .remove(id: target.id)
        }
    }

    /// Notes whose facts sit entirely inside `text`, with nothing `text` contradicts.
    static func lessSpecificNotes(than text: String, in items: [CoachMemoryItem], at date: Date = Date()) -> [CoachMemoryItem] {
        effectiveItems(items, at: date).filter { isStricter(text, than: $0.content) }
    }

    /// The note already on file that says everything `text` says, and is not poorer.
    static func coveringNote(for text: String, in items: [CoachMemoryItem], at date: Date = Date()) -> CoachMemoryItem? {
        let keepers = effectiveItems(items, at: date).filter {
            covers($0.content, text) && !isStricter(text, than: $0.content)
        }
        return keepers.max { isPreferable($1, to: $0) }
    }

    static func retainedNotes(for update: CoachMemoryUpdate, in items: [CoachMemoryItem], at date: Date = Date()) -> [String] {
        let live = effectiveItems(items, at: date)
        switch update.operation {
        case .update, .refile, .remove:
            let reference = update.replaces.isEmpty ? update.text : update.replaces
            return [match(reference, in: live, section: update.operation == .refile ? nil : update.section, at: date)?.content].compactMap { $0 }
        case .merge:
            let first = match(update.replaces, in: live, section: nil, at: date)?.content
            let second = match(update.alsoReplaces, in: live, section: nil, at: date)?.content
            return [first, second].compactMap { $0 }
        case .add:
            return []
        }
    }

    /// True when `keeper` already contains every specific in `candidate`.
    static func covers(_ keeper: String, _ candidate: String) -> Bool {
        guard !contradicts(keeper, candidate) else { return false }
        let candidateWords = comparisonWords(in: candidate)
        guard !candidateWords.isEmpty else { return false }
        return candidateWords.isSubset(of: comparisonWords(in: keeper))
    }

    /// True when `candidate` keeps every specific in `existing` and adds at least one.
    static func isStricter(_ candidate: String, than existing: String) -> Bool {
        guard !contradicts(candidate, existing) else { return false }
        let candidateWords = comparisonWords(in: candidate)
        let existingWords = comparisonWords(in: existing)
        return existingWords.isSubset(of: candidateWords) && candidateWords.count > existingWords.count
    }

    /// A name, a number, or a negation that disagrees. Those are different facts.
    static func contradicts(_ lhs: String, _ rhs: String) -> Bool {
        if hasNegation(lhs) != hasNegation(rhs) { return true }
        let leftNumbers = comparisonWords(in: lhs).filter { $0.allSatisfy(\.isNumber) }
        let rightNumbers = comparisonWords(in: rhs).filter { $0.allSatisfy(\.isNumber) }
        guard !leftNumbers.isEmpty, !rightNumbers.isEmpty else { return false }
        return !leftNumbers.isSubset(of: rightNumbers) && !rightNumbers.isSubset(of: leftNumbers)
    }

    /// True when `replacement` drops a specific the sources had, other than a number it corrects.
    static func losesSpecifics(from sources: [String], replacement: String) -> Bool {
        let kept = comparisonWords(in: replacement)
        let dropped = sources.reduce(into: Set<String>()) { partial, source in
            partial.formUnion(comparisonWords(in: source).subtracting(kept))
        }
        guard !dropped.isEmpty else { return false }
        if dropped.contains(where: { !$0.allSatisfy(\.isNumber) }) { return true }
        if kept.contains(where: { $0.allSatisfy(\.isNumber) }) { return false }
        return !sources.contains { hasNegation($0) != hasNegation(replacement) }
    }

    /// The note worth keeping when two say the same thing: more specifics, then
    /// the longer wording, then the older one. Recency does not win.
    static func isPreferable(_ candidate: CoachMemoryItem, to other: CoachMemoryItem) -> Bool {
        let candidateWords = comparisonWords(in: candidate.content).count
        let otherWords = comparisonWords(in: other.content).count
        if candidateWords != otherWords { return candidateWords > otherWords }
        if candidate.content.count != other.content.count { return candidate.content.count > other.content.count }
        if candidate.createdAt != other.createdAt { return candidate.createdAt < other.createdAt }
        return candidate.id.uuidString < other.id.uuidString
    }

    static func noteDominates(_ keeper: CoachMemoryItem, over other: CoachMemoryItem) -> Bool {
        guard keeper.id != other.id else { return false }
        guard !contradicts(keeper.content, other.content) else { return false }
        guard covers(keeper.content, other.content) else { return false }
        if isStricter(keeper.content, than: other.content) { return true }
        return comparisonWords(in: keeper.content) == comparisonWords(in: other.content) && isPreferable(keeper, to: other)
    }

    /// Specifics used to compare notes. Light stemming, so "eats" and "eating"
    /// are one word, and a single differing number stays visible.
    static func comparisonWords(in text: String) -> Set<String> {
        let stop: Set<String> = [
            "about", "after", "again", "also", "always", "another", "around", "because", "been", "before",
            "being", "between", "both", "could", "does", "doing", "during", "each", "either", "every",
            "feels", "from", "going", "goes", "have", "having", "help", "helps", "helpful", "into", "just",
            "keeps", "like", "likely", "makes", "many", "more", "most", "much", "often", "only", "other",
            "over", "part", "person", "really", "said", "same", "says", "seems", "since", "some", "something",
            "still", "such", "than", "that", "their", "them", "then", "there", "these", "they", "thing",
            "things", "this", "those", "through", "told", "under", "until", "uses", "very", "want", "wants",
            "when", "where", "which", "while", "will", "with", "within", "would", "your", "stated", "inferred",
            "january", "february", "march", "april", "june", "july", "august", "september", "october",
            "november", "december", "2025", "2026", "2027", "tends", "tend", "usually", "sometimes"
        ]
        let tokens = text.lowercased()
            .replacingOccurrences(of: "’", with: "'")
            .replacingOccurrences(of: "'", with: "")
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
        return Set(tokens.compactMap { token in
            if token.allSatisfy(\.isNumber), !token.isEmpty, !stop.contains(token) { return token }
            guard token.count >= 4 else { return nil }
            let word = comparisonStem(token)
            return stop.contains(word) || stop.contains(token) ? nil : word
        })
    }

    private static func comparisonStem(_ token: String) -> String {
        var word = token
        if word.hasSuffix("s"), !word.hasSuffix("ss"), word.count >= 4 {
            let stem = String(word.dropLast())
            if stem.count >= 3 { word = stem }
        }
        if word.hasSuffix("ing"), word.count >= 6 {
            let stem = String(word.dropLast(3))
            if stem.count >= 3 { word = stem }
        }
        return word
    }

    static func hasNegation(_ text: String) -> Bool {
        let cues: Set<String> = [
            "not", "no", "never", "dont", "doesnt", "cannot", "cant", "without", "nobody", "nothing"
        ]
        let tokens = text.lowercased()
            .replacingOccurrences(of: "’", with: "'")
            .replacingOccurrences(of: "'", with: "")
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
        return tokens.contains { cues.contains($0) }
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
