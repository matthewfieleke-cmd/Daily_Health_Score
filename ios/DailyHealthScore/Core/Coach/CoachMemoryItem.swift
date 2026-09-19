import Foundation

enum CoachMemoryCategory: String, CaseIterable, Identifiable, Codable, Sendable {
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

    var label: String {
        switch self {
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
    case coachInterpretation
    case legacyCoachNotes

    var label: String {
        switch self {
        case .userStated: return "You said this"
        case .userConfirmed: return "You confirmed this"
        case .computedFromRecords: return "Computed from app records"
        case .coachInterpretation: return "Coach interpretation (unconfirmed)"
        case .legacyCoachNotes: return "Earlier coach note (unconfirmed)"
        }
    }

    var isConfirmedByUser: Bool {
        self == .userStated || self == .userConfirmed
    }
}

enum CoachMemoryConfirmation: String, Codable, Sendable {
    case unconfirmed
    case confirmed
    case needsReview
    case expired
}

struct CoachMemoryItem: Identifiable, Equatable, Codable, Sendable {
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

enum CoachMemoryFingerprint {
    static func fingerprint(_ content: String) -> String {
        let normalized = content
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        var hash: UInt64 = 5381
        for byte in normalized.utf8 {
            hash = hash &* 33 &+ UInt64(byte)
        }
        return String(hash, radix: 16)
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

    static func itemsByOverridingContradictions(_ items: [CoachMemoryItem], at date: Date = Date()) -> [CoachMemoryItem] {
        let live = effectiveItems(items, at: date)
        var kept: [CoachMemoryItem] = []
        for item in live.sorted(by: { ($0.lastConfirmedAt ?? $0.createdAt) > ($1.lastConfirmedAt ?? $1.createdAt) }) {
            let newer = kept.contains { existing in
                existing.category == item.category
                    && existing.provenance.isConfirmedByUser
                    && !item.provenance.isConfirmedByUser
                    && existing.id != item.id
            }
            if newer { continue }
            kept.append(item)
        }
        return kept.sorted { $0.createdAt > $1.createdAt }
    }

    static func promptBlock(
        items: [CoachMemoryItem],
        tombstonesIgnored: Bool = true,
        at date: Date = Date()
    ) -> String {
        let live = itemsByOverridingContradictions(items, at: date)
        if live.isEmpty { return "No saved coach memories yet." }
        func section(_ title: String, _ subset: [CoachMemoryItem]) -> String? {
            guard !subset.isEmpty else { return nil }
            let lines = subset.prefix(8).map { item in
                "- [\(item.category.label)] \(item.displayContent) (\(item.provenance.label))"
            }
            return "\(title)\n" + lines.joined(separator: "\n")
        }
        let confirmed = live.filter { $0.provenance.isConfirmedByUser }
        let computed = items.filter { $0.provenance == .computedFromRecords && !$0.isDeleted }
        let interpretations = live.filter { $0.provenance == .coachInterpretation }
        let legacy = live.filter { $0.provenance == .legacyCoachNotes }
        let awaiting = items.filter {
            !$0.isDeleted && $0.isTemporary && ($0.confirmation == .needsReview || ($0.expiresAt ?? .distantFuture) < date)
        }
        var parts = [
            section("CONFIRMED BY YOU (treat as personal facts):", confirmed),
            section("COMPUTED FROM APP RECORDS (not personal biography):", computed),
            section("COACH INTERPRETATIONS (unconfirmed; do not treat as facts):", interpretations),
            section("EARLIER COACH NOTES (unconfirmed legacy):", legacy)
        ].compactMap { $0 }
        if !awaiting.isEmpty {
            parts.append(
                "TEMPORARY CIRCUMSTANCES AWAITING REVIEW: do not treat these as permanent constraints."
            )
        }
        _ = tombstonesIgnored
        return parts.joined(separator: "\n")
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
