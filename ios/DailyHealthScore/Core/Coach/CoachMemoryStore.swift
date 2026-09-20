import Combine
import Foundation
import SwiftData

@MainActor
final class CoachMemoryStore: ObservableObject {
    static let recentTurnLimit = 10

    private let modelContext: ModelContext

    @Published private(set) var turns: [CoachChatTurn] = []
    @Published private(set) var allTurns: [CoachChatTurn] = []
    @Published private(set) var threads: [CoachThread] = []
    @Published private(set) var bridges: [CoachBridge] = []
    @Published private(set) var openThreadID: UUID?
    @Published private(set) var runningSummary: String = ""
    @Published private(set) var profile: CoachUserProfile = CoachUserProfile()
    @Published private(set) var memories: [CoachMemoryItem] = []
    @Published private(set) var memoryRevision: Int = 0
    @Published private(set) var cachedDailyCard: DailyCoachCardContent?
    @Published private(set) var cachedDailyCardDateKey: String = ""

    var openThread: CoachThread? {
        threads.first { $0.id == openThreadID }
    }

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
        allTurns = entities.compactMap { $0.toTurn() }
        migrateLegacyTurnsIfNeeded()
        let threadEntities = (try? modelContext.fetch(FetchDescriptor<CoachThreadEntity>())) ?? []
        threads = threadEntities.compactMap { $0.toThread() }.sorted { $0.lastMessageAt > $1.lastMessageAt }
        let bridgeEntities = (try? modelContext.fetch(FetchDescriptor<CoachBridgeEntity>())) ?? []
        bridges = bridgeEntities.compactMap { $0.toBridge() }.sorted { $0.createdAt > $1.createdAt }
        if let openThreadID {
            turns = allTurns.filter { $0.threadId == openThreadID }
        } else {
            turns = allTurns
        }

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
        var stored = turn
        if stored.threadId == nil {
            stored.threadId = openThreadID ?? ensureInboxThread().id
            openThreadID = stored.threadId
        }
        modelContext.insert(CoachChatMessageEntity(turn: stored))
        if let threadId = stored.threadId, var thread = threads.first(where: { $0.id == threadId }) {
            thread.lastMessageAt = stored.createdAt
            thread.updatedAt = stored.createdAt
            thread.status = .active
            upsertThread(thread)
        }
        try? modelContext.save()
        reload()
        trimTurnsIfNeeded()
    }

    func parkStaleThreads(now: Date = Date()) {
        persistParked(CoachThreadLogic.parkStale(threads, now: now))
        reload()
    }

    @discardableResult
    func open(_ launch: CoachChatLaunch, now: Date = Date()) -> CoachThread? {
        persistParked(CoachThreadLogic.parkStale(threads, now: now))
        switch launch {
        case .recents:
            openThreadID = nil
            reload()
            return nil
        case .inbox:
            return startInbox(now: now)
        case .continueThread:
            if let existing = CoachThreadLogic.continueThread(in: threads) {
                return openThread(existing.id)
            }
            return startInbox(now: now)
        case .room(let room):
            return resumeOrStart(room: room, now: now)
        case .thread(let id):
            return openThread(id)
        case .focus(let focus):
            return resumeOrStart(room: CoachRoom.from(focus: focus), now: now)
        }
    }

    @discardableResult
    func openThread(_ id: UUID) -> CoachThread? {
        guard threads.contains(where: { $0.id == id }) else { return nil }
        openThreadID = id
        reload()
        return openThread
    }

    @discardableResult
    func startInbox(now: Date = Date()) -> CoachThread {
        persistParked(CoachThreadLogic.parkActive(in: .inbox, threads: threads, now: now))
        let thread = CoachThread(room: .inbox, title: CoachRoom.inbox.label, createdAt: now, updatedAt: now, lastMessageAt: now)
        upsertThread(thread)
        openThreadID = thread.id
        reload()
        return thread
    }

    @discardableResult
    func resumeOrStart(room: CoachRoom, now: Date = Date()) -> CoachThread {
        persistParked(CoachThreadLogic.parkStale(threads, now: now))
        if let active = CoachThreadLogic.active(in: room, threads: threads) {
            return openThread(active.id) ?? active
        }
        persistParked(CoachThreadLogic.parkActive(in: room, threads: threads, now: now))
        let thread = CoachThread(room: room, title: room.label, createdAt: now, updatedAt: now, lastMessageAt: now)
        upsertThread(thread)
        openThreadID = thread.id
        reload()
        return thread
    }

    /// After a user turn: file inbox or refile+rename when the talk moved.
    func classifyOpenThreadIfNeeded(latestUserText: String, now: Date = Date()) {
        guard var thread = openThread else { return }
        let userTexts = allTurns
            .filter { $0.threadId == thread.id && $0.role == .user }
            .sorted { $0.createdAt < $1.createdAt }
            .map(\.text)
        guard let destination = CoachThreadLogic.filingDecision(
            room: thread.room,
            userTexts: userTexts,
            latestUserText: latestUserText
        ) else {
            if thread.room == .inbox, userTexts.count == 1 {
                thread.title = CoachThreadLogic.title(from: userTexts, room: .inbox)
                upsertThread(thread)
                reload()
            }
            return
        }
        refile(threadID: thread.id, to: destination, now: now)
    }

    func refile(threadID: UUID, to room: CoachRoom, now: Date = Date()) {
        guard var thread = threads.first(where: { $0.id == threadID }), thread.room != room else { return }
        let from = thread.room
        persistParked(CoachThreadLogic.parkActive(in: room, except: threadID, threads: threads, now: now))
        let userTexts = allTurns
            .filter { $0.threadId == threadID && $0.role == .user }
            .sorted { $0.createdAt < $1.createdAt }
            .map(\.text)
        thread.room = room
        thread.title = CoachThreadLogic.title(from: userTexts, room: room)
        thread.status = .active
        thread.updatedAt = now
        upsertThread(thread)
        let bridge = CoachBridge(
            text: CoachThreadLogic.bridgeText(from: from, to: room, title: thread.title),
            fromRoom: from,
            toRoom: room,
            createdAt: now,
            sourceThreadId: threadID
        )
        modelContext.insert(CoachBridgeEntity(bridge: bridge))
        try? modelContext.save()
        reload()
    }

    func markHealthMentioned(now: Date = Date(), calendar: Calendar = .current) {
        guard var thread = openThread else { return }
        thread.healthMentionWindowKey = CoachThreadLogic.healthWindowKey(now: now, calendar: calendar)
        upsertThread(thread)
        reload()
    }

    func hasMentionedHealthThisWindow(now: Date = Date(), calendar: Calendar = .current) -> Bool {
        guard let thread = openThread else { return false }
        return thread.healthMentionWindowKey == CoachThreadLogic.healthWindowKey(now: now, calendar: calendar)
    }

    func recentBridges(limit: Int = 2) -> [CoachBridge] {
        Array(bridges.prefix(limit))
    }

    private func ensureInboxThread() -> CoachThread {
        if let open = openThread { return open }
        if let existing = CoachThreadLogic.continueThread(in: threads) { return existing }
        return startInbox()
    }

    private func persistParked(_ updated: [CoachThread]) {
        for thread in updated where threads.first(where: { $0.id == thread.id })?.status != thread.status {
            upsertThread(thread)
        }
    }

    private func upsertThread(_ thread: CoachThread) {
        let id = thread.id
        let descriptor = FetchDescriptor<CoachThreadEntity>(predicate: #Predicate { $0.id == id })
        if let existing = try? modelContext.fetch(descriptor).first {
            existing.apply(thread)
        } else {
            modelContext.insert(CoachThreadEntity(thread: thread))
        }
        try? modelContext.save()
        if let index = threads.firstIndex(where: { $0.id == thread.id }) {
            threads[index] = thread
        } else {
            threads.append(thread)
        }
    }

    private func migrateLegacyTurnsIfNeeded() {
        let orphans = allTurns.filter { $0.threadId == nil }
        guard !orphans.isEmpty else { return }
        let existing = ((try? modelContext.fetch(FetchDescriptor<CoachThreadEntity>())) ?? [])
            .compactMap { $0.toThread() }
        let thread: CoachThread
        if let legacy = existing.first(where: { $0.title == "Earlier conversation" }) {
            thread = legacy
        } else {
            let created = CoachThread(
                room: .inbox,
                title: "Earlier conversation",
                status: .parked,
                createdAt: orphans.first?.createdAt ?? Date(),
                updatedAt: orphans.last?.createdAt ?? Date(),
                lastMessageAt: orphans.last?.createdAt ?? Date()
            )
            upsertThread(created)
            thread = created
        }
        let messages = (try? modelContext.fetch(FetchDescriptor<CoachChatMessageEntity>())) ?? []
        for message in messages where message.threadId == nil {
            message.threadId = thread.id
        }
        try? modelContext.save()
        allTurns = messages.compactMap { $0.toTurn() }
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

    /// Facts the person just said, in their own words. Does not bump revision,
    /// so an in-flight reply is not cancelled.
    func ingestUserStatedFacts(from message: String) {
        let blocked = tombstones
        var added = false
        for item in CoachPhDMemoryExtractor.items(from: message) {
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
        let threadRows = (try? modelContext.fetch(FetchDescriptor<CoachThreadEntity>())) ?? []
        for row in threadRows { modelContext.delete(row) }
        let bridgeRows = (try? modelContext.fetch(FetchDescriptor<CoachBridgeEntity>())) ?? []
        for row in bridgeRows { modelContext.delete(row) }
        try? modelContext.save()
        turns = []
        allTurns = []
        threads = []
        bridges = []
        openThreadID = nil
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

    func userTexts(in threadID: UUID) -> [String] {
        allTurns
            .filter { $0.threadId == threadID && $0.role == .user }
            .sorted { $0.createdAt < $1.createdAt }
            .map(\.text)
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
