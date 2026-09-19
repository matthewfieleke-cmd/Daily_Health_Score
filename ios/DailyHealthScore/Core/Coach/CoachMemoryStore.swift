import Combine
import Foundation
import SwiftData

@MainActor
final class CoachMemoryStore: ObservableObject {
    static let recentTurnLimit = 10

    private let modelContext: ModelContext

    @Published private(set) var turns: [CoachChatTurn] = []
    @Published private(set) var runningSummary: String = ""
    @Published private(set) var profile: CoachUserProfile = CoachUserProfile()
    @Published private(set) var memories: [CoachMemoryItem] = []
    @Published private(set) var memoryRevision: Int = 0
    @Published private(set) var cachedDailyCard: DailyCoachCardContent?
    @Published private(set) var cachedDailyCardDateKey: String = ""

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        reload()
        migrateLegacyProfileNotesIfNeeded()
    }

    func reload() {
        let messageDescriptor = FetchDescriptor<CoachChatMessageEntity>(
            sortBy: [SortDescriptor(\.createdAt, order: .forward)]
        )
        let entities = (try? modelContext.fetch(messageDescriptor)) ?? []
        turns = entities.compactMap { $0.toTurn() }

        let memoryEntities = (try? modelContext.fetch(FetchDescriptor<CoachMemoryItemEntity>())) ?? []
        memories = memoryEntities.compactMap { $0.toItem() }

        let state = fetchOrCreateState()
        runningSummary = state.runningSummary
        cachedDailyCardDateKey = state.dailyCardDateKey
        if state.memoryRevision != memoryRevision {
            memoryRevision = state.memoryRevision
        }
        var storedProfile = CoachUserProfile()
        if let data = state.profileJSON.data(using: .utf8),
           let decoded = try? JSONDecoder().decode(CoachUserProfile.self, from: data) {
            storedProfile = decoded
        }
        if memories.contains(where: { !$0.isDeleted }) {
            profile = CoachMemoryLogic.profile(from: memories)
        } else {
            profile = storedProfile
        }
        if let data = state.dailyCardJSON.data(using: .utf8),
           let card = try? JSONDecoder().decode(DailyCoachCardContent.self, from: data) {
            cachedDailyCard = card
        } else {
            cachedDailyCard = nil
        }
    }

    var tombstones: Set<String> {
        let state = fetchOrCreateState()
        guard let data = state.deletedFingerprintsJSON.data(using: .utf8),
              let decoded = try? JSONDecoder().decode([String].self, from: data) else {
            return []
        }
        return Set(decoded)
    }

    var promptMemoryBlock: String {
        CoachMemoryLogic.promptBlock(items: memories)
    }

    var effectiveMemories: [CoachMemoryItem] {
        CoachMemoryLogic.itemsByOverridingContradictions(memories)
    }

    func append(_ turn: CoachChatTurn) {
        modelContext.insert(CoachChatMessageEntity(turn: turn))
        try? modelContext.save()
        reload()
        trimTurnsIfNeeded()
    }

    func replaceSummary(_ summary: String) {
        let state = fetchOrCreateState()
        state.runningSummary = summary.trimmingCharacters(in: .whitespacesAndNewlines)
        state.updatedAt = Date()
        try? modelContext.save()
        runningSummary = state.runningSummary
    }

    func updateProfile(_ profile: CoachUserProfile) {
        let state = fetchOrCreateState()
        if let data = try? JSONEncoder().encode(profile),
           let json = String(data: data, encoding: .utf8) {
            state.profileJSON = json
        }
        state.updatedAt = Date()
        try? modelContext.save()
        self.profile = profile
    }

    /// Model-extracted notes stay unconfirmed interpretations. Tombstones win.
    func ingestModelProfileUpdate(_ incoming: CoachUserProfile, generationRevision: Int) -> Bool {
        guard generationRevision == memoryRevision else { return false }
        let blocked = tombstones
        var added = false
        for item in CoachMemoryLogic.interpretationItems(from: incoming, recordedAt: Date()) {
            if CoachMemoryLogic.isTombstoned(content: item.content, tombstones: blocked) { continue }
            if memories.contains(where: {
                !$0.isDeleted && $0.contentFingerprint == item.contentFingerprint
            }) { continue }
            upsert(item)
            added = true
        }
        if added {
            persistDerivedProfile()
            reload()
        }
        return added
    }

    func mergeProfile(_ incoming: CoachUserProfile) {
        _ = ingestModelProfileUpdate(incoming, generationRevision: memoryRevision)
    }

    func save(_ item: CoachMemoryItem) {
        var stored = item
        stored.contentFingerprint = CoachMemoryFingerprint.fingerprint(item.content)
        upsert(stored)
        persistDerivedProfile()
        reload()
    }

    func confirm(_ item: CoachMemoryItem, stillApplies: Bool, now: Date = Date()) {
        var updated = item
        if stillApplies {
            updated.confirmation = .confirmed
            updated.provenance = .userConfirmed
            updated.lastConfirmedAt = now
            if updated.isTemporary {
                updated.expiresAt = now.addingTimeInterval(14 * 86_400)
            }
        } else {
            delete(updated)
            return
        }
        save(updated)
    }

    func correct(item: CoachMemoryItem, content: String, category: CoachMemoryCategory) {
        var replacement = CoachMemoryItem(
            category: category,
            content: content,
            provenance: .userStated,
            createdAt: Date(),
            lastConfirmedAt: Date(),
            associatedGoalId: item.associatedGoalId,
            confirmation: .confirmed,
            isTemporary: item.isTemporary || category == .circumstance
        )
        if replacement.isTemporary {
            replacement.expiresAt = Date().addingTimeInterval(14 * 86_400)
        }
        var previous = item
        previous.supersededById = replacement.id
        upsert(previous)
        upsert(replacement)
        persistDerivedProfile()
        bumpRevision(removing: [item.content])
        reload()
    }

    func delete(_ item: CoachMemoryItem) {
        var deleted = item
        deleted.isDeleted = true
        upsert(deleted)
        addTombstone(item.contentFingerprint)
        persistDerivedProfile()
        bumpRevision(removing: [item.content])
        reload()
    }

    func saveDailyCard(_ card: DailyCoachCardContent, dateKey: String) {
        let state = fetchOrCreateState()
        state.dailyCardDateKey = dateKey
        if let data = try? JSONEncoder().encode(card),
           let json = String(data: data, encoding: .utf8) {
            state.dailyCardJSON = json
        }
        state.updatedAt = Date()
        try? modelContext.save()
        cachedDailyCardDateKey = dateKey
        cachedDailyCard = card
    }

    func recordFeedback(target: String, useful: Bool, goalId: UUID? = nil) {
        modelContext.insert(CoachLocalFeedbackEntity(target: target, useful: useful, goalId: goalId))
        try? modelContext.save()
    }

    func clearAllMemory() {
        let messages = (try? modelContext.fetch(FetchDescriptor<CoachChatMessageEntity>())) ?? []
        for message in messages {
            modelContext.delete(message)
        }
        let states = (try? modelContext.fetch(FetchDescriptor<CoachMemoryStateEntity>())) ?? []
        for state in states {
            modelContext.delete(state)
        }
        let items = (try? modelContext.fetch(FetchDescriptor<CoachMemoryItemEntity>())) ?? []
        for item in items {
            modelContext.delete(item)
        }
        try? modelContext.save()
        turns = []
        runningSummary = ""
        profile = CoachUserProfile()
        memories = []
        memoryRevision = 0
        cachedDailyCard = nil
        cachedDailyCardDateKey = ""
    }

    func recentTurnsForPrompt(limit: Int = CoachMemoryStore.recentTurnLimit) -> [CoachChatTurn] {
        Array(turns.suffix(limit))
    }

    private func migrateLegacyProfileNotesIfNeeded() {
        guard memories.isEmpty else { return }
        guard !profile.isEmpty else { return }
        for item in CoachMemoryLogic.legacyItems(from: profile, recordedAt: Date()) {
            upsert(item)
        }
        persistDerivedProfile()
        reload()
    }

    private func persistDerivedProfile() {
        let snapshot = pendingMemorySnapshot()
        memories = snapshot
        updateProfile(CoachMemoryLogic.profile(from: snapshot))
    }

    private func pendingMemorySnapshot() -> [CoachMemoryItem] {
        ((try? modelContext.fetch(FetchDescriptor<CoachMemoryItemEntity>())) ?? [])
            .compactMap { $0.toItem() }
    }

    private func upsert(_ item: CoachMemoryItem) {
        let id = item.id
        let descriptor = FetchDescriptor<CoachMemoryItemEntity>(
            predicate: #Predicate { $0.id == id }
        )
        if let existing = try? modelContext.fetch(descriptor).first {
            existing.apply(item)
        } else {
            modelContext.insert(CoachMemoryItemEntity(item: item))
        }
        try? modelContext.save()
        if let index = memories.firstIndex(where: { $0.id == item.id }) {
            memories[index] = item
        } else {
            memories.append(item)
        }
    }

    private func addTombstone(_ fingerprint: String) {
        var stamps = tombstones
        stamps.insert(fingerprint)
        let state = fetchOrCreateState()
        if let data = try? JSONEncoder().encode(Array(stamps)),
           let json = String(data: data, encoding: .utf8) {
            state.deletedFingerprintsJSON = json
        }
        try? modelContext.save()
    }

    private func bumpRevision(removing contents: [String]) {
        let state = fetchOrCreateState()
        state.memoryRevision += 1
        state.runningSummary = CoachMemoryLogic.sanitizeSummary(state.runningSummary, removing: contents)
        state.dailyCardJSON = ""
        state.dailyCardDateKey = ""
        state.updatedAt = Date()
        try? modelContext.save()
        memoryRevision = state.memoryRevision
        runningSummary = state.runningSummary
        cachedDailyCard = nil
        cachedDailyCardDateKey = ""
    }

    private func trimTurnsIfNeeded() {
        let keep = 80
        guard turns.count > keep else { return }
        let extras = turns.count - keep
        let descriptor = FetchDescriptor<CoachChatMessageEntity>(
            sortBy: [SortDescriptor(\.createdAt, order: .forward)]
        )
        guard let entities = try? modelContext.fetch(descriptor) else { return }
        for entity in entities.prefix(extras) {
            modelContext.delete(entity)
        }
        try? modelContext.save()
        reload()
    }

    private func fetchOrCreateState() -> CoachMemoryStateEntity {
        let descriptor = FetchDescriptor<CoachMemoryStateEntity>()
        if let existing = try? modelContext.fetch(descriptor).first {
            return existing
        }
        let created = CoachMemoryStateEntity()
        modelContext.insert(created)
        try? modelContext.save()
        return created
    }
}
