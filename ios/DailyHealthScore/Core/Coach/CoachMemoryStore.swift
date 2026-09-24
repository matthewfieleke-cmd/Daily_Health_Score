import Combine
import Foundation
import SwiftData

/// What a new chat will become once the person sends something. Held in memory
/// only, so opening a chat and backing out never leaves an empty row.
struct CoachThreadSeed: Equatable, Sendable {
    var kind: CoachThreadKind = .conversation
    var pillar: CoachPillar = .general
    var provisionalTitle: String = ""
    var contextNote: String = ""
    var goalId: UUID?
    /// Coach messages the chat opens with (the check-in text, the intake opener).
    var coachOpeners: [String] = []
    /// True when the created thread should be linked to the current check-in.
    var linksCheckIn: Bool = false
}

@MainActor
final class CoachMemoryStore: ObservableObject {
    static let recentTurnLimit = 10

    private let modelContext: ModelContext

    /// Turns of the open chat. Empty for a chat that has not started yet.
    @Published private(set) var turns: [CoachChatTurn] = []
    @Published private(set) var allTurns: [CoachChatTurn] = []
    @Published private(set) var threads: [CoachThread] = []
    @Published private(set) var openThreadID: UUID?
    @Published private(set) var pendingSeed: CoachThreadSeed?
    @Published private(set) var runningSummary: String = ""
    @Published private(set) var profile: CoachUserProfile = CoachUserProfile()
    @Published private(set) var memories: [CoachMemoryItem] = []
    @Published private(set) var changes: [CoachMemoryChange] = []
    @Published private(set) var memoryRevision: Int = 0
    @Published private(set) var cachedCheckIn: CoachCheckIn?
    @Published private(set) var cachedCheckInKey: String = ""

    var openThread: CoachThread? {
        threads.first { $0.id == openThreadID }
    }

    /// What the chat screen shows: the open chat, or the openers of a chat about to start.
    var visibleTurns: [CoachChatTurn] {
        if openThreadID != nil { return turns }
        guard let seed = pendingSeed else { return [] }
        return seed.coachOpeners.enumerated().map { index, text in
            CoachChatTurn(
                id: seedTurnID(index: index),
                role: .coach,
                text: text,
                createdAt: Date(timeIntervalSince1970: Double(index))
            )
        }
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
        let liveEntities = backfillThreadRows(threadEntities)
        threads = CoachThreadLogic.sorted(liveEntities.map { $0.toThread() })
        if let openThreadID, threads.contains(where: { $0.id == openThreadID }) {
            turns = allTurns.filter { $0.threadId == openThreadID }
        } else {
            turns = []
        }

        let memoryEntities = (try? modelContext.fetch(FetchDescriptor<CoachMemoryItemEntity>())) ?? []
        memories = memoryEntities.compactMap { $0.toItem() }
        let changeEntities = (try? modelContext.fetch(FetchDescriptor<CoachMemoryChangeEntity>())) ?? []
        changes = changeEntities.compactMap { $0.toChange() }.sorted { $0.createdAt > $1.createdAt }

        let state = fetchOrCreateState()
        runningSummary = state.runningSummary
        cachedCheckInKey = state.dailyCardDateKey
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
           let checkIn = try? JSONDecoder().decode(CoachCheckIn.self, from: data) {
            cachedCheckIn = checkIn
        } else {
            cachedCheckIn = nil
        }
    }

    // MARK: - Memory reads

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

    var liveMemoryCount: Int { effectiveMemories.count }

    var needsAcquaintance: Bool {
        CoachAcquaintance.isNeeded(threads: threads, liveMemoryCount: liveMemoryCount)
    }

    /// Coach edits the person has not undone, newest first.
    var recentChanges: [CoachMemoryChange] {
        let cutoff = Date().addingTimeInterval(-14 * 86_400)
        return changes
            .filter { !$0.isUndone && $0.createdAt >= cutoff }
            .prefix(20)
            .map { $0 }
    }

    func recentConversationsBlock(now: Date = Date()) -> String {
        CoachThreadLogic.recentConversationsBlock(threads, excluding: openThreadID, now: now)
    }

    // MARK: - Chats

    @discardableResult
    func open(_ launch: CoachChatLaunch) -> CoachThread? {
        switch launch {
        case .chats:
            openThreadID = nil
            pendingSeed = nil
        case .newChat, .compose:
            openThreadID = nil
            pendingSeed = CoachThreadSeed()
        case .acquaint:
            if let existing = CoachAcquaintance.existingThread(in: threads) {
                openThreadID = existing.id
                pendingSeed = nil
            } else {
                openThreadID = nil
                pendingSeed = CoachThreadSeed(
                    kind: .acquaintance,
                    pillar: .general,
                    provisionalTitle: "Getting acquainted",
                    contextNote: "The first getting-acquainted conversation.",
                    coachOpeners: [CoachAcquaintance.opener]
                )
            }
        case .replyToCheckIn:
            if let checkIn = cachedCheckIn,
               let replyID = checkIn.replyThreadID,
               threads.contains(where: { $0.id == replyID }) {
                openThreadID = replyID
                pendingSeed = nil
            } else if let checkIn = cachedCheckIn {
                openThreadID = nil
                pendingSeed = CoachThreadSeed(
                    kind: .checkInReply,
                    pillar: .general,
                    provisionalTitle: "\(checkIn.kind.title) · \(shortDate(checkIn.dateKey))",
                    contextNote: "Reply to the \(checkIn.kind.title.lowercased()) for \(DateHelpers.formatDisplayDate(checkIn.dateKey)). The card said: \(checkIn.spokenText)",
                    coachOpeners: [checkIn.spokenText],
                    linksCheckIn: true
                )
            } else {
                openThreadID = nil
                pendingSeed = CoachThreadSeed()
            }
        case .focus(let focus):
            openThreadID = nil
            pendingSeed = CoachThreadSeed(
                kind: .conversation,
                pillar: CoachPillar.from(focus: focus),
                provisionalTitle: focus.title,
                contextNote: "Started from the \(focus.title) card. \(focus.valueSummary)".limitedToCoachBudget(400),
                goalId: focus.goalId
            )
        case .goal(let goalId):
            openThreadID = nil
            pendingSeed = CoachThreadSeed(
                kind: .goal,
                pillar: .general,
                provisionalTitle: "SMART goal",
                contextNote: "Started from a saved SMART goal.",
                goalId: goalId
            )
        case .thread(let id):
            if threads.contains(where: { $0.id == id }) {
                openThreadID = id
                pendingSeed = nil
            } else {
                openThreadID = nil
                pendingSeed = CoachThreadSeed()
            }
        }
        reload()
        return openThread
    }

    /// Saves a message into the open chat, creating the chat on the first one.
    func append(_ turn: CoachChatTurn) {
        var stored = turn
        let threadID: UUID
        if let open = openThreadID, threads.contains(where: { $0.id == open }) {
            threadID = open
        } else {
            let opener: String?
            if turn.role == .user {
                opener = turn.text.isEmpty && !turn.photoFileNames.isEmpty ? "Photo" : turn.text
            } else {
                opener = nil
            }
            threadID = createThread(
                from: pendingSeed ?? CoachThreadSeed(),
                firstUserText: opener,
                at: turn.createdAt
            )
            pendingSeed = nil
        }
        stored.threadId = threadID
        openThreadID = threadID
        modelContext.insert(CoachChatMessageEntity(turn: stored))
        try? modelContext.save()
        touchThread(threadID, with: stored)
        reload()
    }

    /// Title, summary, and pillar the Coach returned with its reply.
    func applyReplyMetadata(threadID: UUID, title: String, summary: String, pillar: CoachPillar) {
        guard var thread = threads.first(where: { $0.id == threadID }) else { return }
        let pillarChanged = thread.pillar != pillar
        if let clean = CoachThreadLogic.sanitizedTitle(title), thread.titleIsProvisional || pillarChanged {
            thread.title = clean
            thread.titleIsProvisional = false
        }
        let cleanSummary = summary
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if !cleanSummary.isEmpty {
            thread.summary = String(cleanSummary.prefix(220))
        }
        thread.pillar = pillar
        thread.updatedAt = Date()
        upsertThread(thread)
        reload()
    }

    func deleteThread(_ id: UUID) {
        let messages = (try? modelContext.fetch(FetchDescriptor<CoachChatMessageEntity>())) ?? []
        let removed = messages.filter { $0.threadId == id }
        CoachPhotoStore.delete(fileNames: removed.flatMap(\.photoFileNames))
        for message in removed {
            modelContext.delete(message)
        }
        let descriptor = FetchDescriptor<CoachThreadEntity>(predicate: #Predicate { $0.id == id })
        if let entity = try? modelContext.fetch(descriptor).first {
            modelContext.delete(entity)
        }
        if cachedCheckIn?.replyThreadID == id {
            var checkIn = cachedCheckIn
            checkIn?.replyThreadID = nil
            writeCheckIn(checkIn, key: cachedCheckInKey)
        }
        try? modelContext.save()
        if openThreadID == id {
            openThreadID = nil
            pendingSeed = CoachThreadSeed()
        }
        reload()
    }

    /// Every chat goes; the memory files stay.
    func deleteAllChats() {
        let messages = (try? modelContext.fetch(FetchDescriptor<CoachChatMessageEntity>())) ?? []
        CoachPhotoStore.delete(fileNames: messages.flatMap(\.photoFileNames))
        for message in messages { modelContext.delete(message) }
        let rows = (try? modelContext.fetch(FetchDescriptor<CoachThreadEntity>())) ?? []
        for row in rows { modelContext.delete(row) }
        if var checkIn = cachedCheckIn, checkIn.replyThreadID != nil {
            checkIn.replyThreadID = nil
            writeCheckIn(checkIn, key: cachedCheckInKey)
        }
        try? modelContext.save()
        openThreadID = nil
        pendingSeed = nil
        turns = []
        allTurns = []
        threads = []
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

    func recentTurnsForPrompt(limit: Int = CoachMemoryStore.recentTurnLimit) -> [CoachChatTurn] {
        Array(turns.suffix(limit))
    }

    // MARK: - Check-in

    func saveCheckIn(_ checkIn: CoachCheckIn, key: String) {
        writeCheckIn(checkIn, key: key)
    }

    // MARK: - Memory writes

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
            if CoachMemoryLogic.hasEquivalent(item.content, in: memories) { continue }
            upsert(item)
            added = true
        }
        if added {
            persistDerivedProfile()
            reload()
        }
    }

    /// Coach edits to the files, applied only if the person did not edit memory
    /// while the reply was generating. Returns what changed, for Undo.
    @discardableResult
    func applyCoachUpdates(
        _ updates: [CoachMemoryUpdate],
        threadID: UUID?,
        generationRevision: Int,
        now: Date = Date()
    ) -> [CoachMemoryChange] {
        guard generationRevision == memoryRevision else { return [] }
        let blocked = tombstones
        var applied: [CoachMemoryChange] = []

        func add(_ update: CoachMemoryUpdate) {
            guard !CoachMemoryLogic.isTombstoned(content: update.text, tombstones: blocked) else { return }
            guard !CoachMemoryLogic.hasEquivalent(update.text, in: memories, at: now) else { return }
            let item = CoachMemoryItem(
                category: CoachMemoryCategory(section: update.section),
                content: update.text,
                provenance: update.basis.provenance,
                createdAt: now,
                confirmation: .unconfirmed
            )
            upsert(item)
            applied.append(record(CoachMemoryChange(
                kind: .added,
                section: update.section,
                itemId: item.id,
                newContent: update.text,
                createdAt: now,
                threadId: threadID
            )))
        }

        for update in updates.prefix(6) {
            switch update.operation {
            case .add:
                add(update)
            case .update:
                guard let target = CoachMemoryLogic.match(update.replaces, in: memories, section: update.section, at: now) else {
                    add(update)
                    continue
                }
                if CoachMemoryFingerprint.normalize(target.content) == CoachMemoryFingerprint.normalize(update.text) { continue }
                guard !CoachMemoryLogic.isTombstoned(content: update.text, tombstones: blocked) else { continue }
                // A stated fact stays stated when the Coach rewrites it.
                let provenance: CoachMemoryProvenance = target.provenance.isStated ? .coachRecorded : update.basis.provenance
                let replacement = CoachMemoryItem(
                    category: CoachMemoryCategory(section: update.section),
                    content: update.text,
                    provenance: provenance,
                    createdAt: now,
                    associatedGoalId: target.associatedGoalId,
                    confirmation: .unconfirmed
                )
                var previous = target
                previous.supersededById = replacement.id
                upsert(previous)
                upsert(replacement)
                applied.append(record(CoachMemoryChange(
                    kind: .updated,
                    section: update.section,
                    itemId: replacement.id,
                    previousItemId: target.id,
                    previousContent: target.content,
                    newContent: update.text,
                    createdAt: now,
                    threadId: threadID
                )))
            case .remove:
                guard let target = CoachMemoryLogic.match(update.replaces, in: memories, section: update.section, at: now) else { continue }
                var deleted = target
                deleted.isDeleted = true
                upsert(deleted)
                addTombstone(target.contentFingerprint)
                applied.append(record(CoachMemoryChange(
                    kind: .removed,
                    section: update.section,
                    itemId: target.id,
                    previousContent: target.content,
                    createdAt: now,
                    threadId: threadID
                )))
            }
        }
        if !applied.isEmpty {
            persistDerivedProfile()
            reload()
        }
        return applied
    }

    /// Reverses one Coach edit. Undoing an add or an update tombstones the
    /// rejected text so the Coach does not write it again.
    func undo(_ change: CoachMemoryChange) {
        guard var stored = changes.first(where: { $0.id == change.id }), !stored.isUndone else { return }
        switch stored.kind {
        case .added:
            if let item = memories.first(where: { $0.id == stored.itemId }) {
                var deleted = item
                deleted.isDeleted = true
                upsert(deleted)
                addTombstone(item.contentFingerprint)
            }
        case .updated:
            if let item = memories.first(where: { $0.id == stored.itemId }) {
                var deleted = item
                deleted.isDeleted = true
                upsert(deleted)
                addTombstone(item.contentFingerprint)
            }
            if let previousID = stored.previousItemId,
               let previous = memories.first(where: { $0.id == previousID }) {
                var restored = previous
                restored.supersededById = nil
                upsert(restored)
            }
        case .removed:
            if let item = memories.first(where: { $0.id == stored.itemId }) {
                var restored = item
                restored.isDeleted = false
                upsert(restored)
                removeTombstone(item.contentFingerprint)
            }
        case .refiled:
            // previousContent carries the original file's storage key.
            if let item = memories.first(where: { $0.id == stored.itemId }),
               let original = CoachMemorySection(rawValue: stored.previousContent) {
                var moved = item
                moved.category = CoachMemoryCategory(section: original)
                upsert(moved)
            }
        }
        stored.isUndone = true
        upsertChange(stored)
        persistDerivedProfile()
        bumpRevision(removing: stored.newContent.isEmpty || stored.kind == .refiled ? [] : [stored.newContent])
        reload()
    }

    /// The person agrees with an inferred note: it becomes a stated fact.
    func confirmInference(_ item: CoachMemoryItem, now: Date = Date()) {
        var confirmed = item
        confirmed.provenance = .userConfirmed
        confirmed.confirmation = .confirmed
        confirmed.lastConfirmedAt = now
        save(confirmed)
    }

    // MARK: - Compiled profile and housekeeping

    /// Fingerprint of the live entries plus the calendar day. The background
    /// is rebuilt when a note, its statedness, or the day changes.
    var memoryFingerprint: String {
        let live = effectiveMemories.sorted { $0.id.uuidString < $1.id.uuidString }
        let body = CoachMemoryFingerprint.profileSource(
            generation: CoachCharter.profileCompilerGeneration,
            day: DateHelpers.localDateKey(),
            entries: live.map {
                CoachMemoryFingerprint.ProfileSourceEntry(
                    id: $0.id.uuidString,
                    section: $0.section.rawValue,
                    stated: $0.provenance.isStated,
                    content: $0.content
                )
            }
        )
        return CoachMemoryFingerprint.fingerprint(body)
    }

    var compiledProfile: String {
        let state = fetchOrCreateState()
        // A stale profile is worse than none: it would contradict the entries.
        guard state.compiledProfileKey == memoryFingerprint else { return "" }
        return state.compiledProfile
    }

    var needsProfileCompile: Bool {
        !effectiveMemories.isEmpty && fetchOrCreateState().compiledProfileKey != memoryFingerprint
    }

    func saveCompiledProfile(_ profile: String) {
        let state = fetchOrCreateState()
        state.compiledProfile = profile
        state.compiledProfileKey = memoryFingerprint
        state.updatedAt = Date()
        try? modelContext.save()
        objectWillChange.send()
    }

    /// Deletes a compiled paragraph after the last note is gone, so the
    /// biography does not stay in the store under a key that no longer matches.
    func discardCompiledProfileIfNotesAreGone() {
        guard effectiveMemories.isEmpty else { return }
        let state = fetchOrCreateState()
        guard !state.compiledProfile.isEmpty else { return }
        state.compiledProfile = ""
        state.compiledProfileKey = memoryFingerprint
        state.updatedAt = Date()
        try? modelContext.save()
        objectWillChange.send()
    }

    /// Housekeeping runs at most daily and only once the files have some weight.
    func shouldReviewFiles(now: Date = Date()) -> Bool {
        guard effectiveMemories.count >= 6 else { return false }
        let state = fetchOrCreateState()
        guard let last = state.lastFilesReviewAt else { return true }
        return now.timeIntervalSince(last) >= 20 * 3600
    }

    func markFilesReviewed(now: Date = Date()) {
        let state = fetchOrCreateState()
        state.lastFilesReviewAt = now
        try? modelContext.save()
    }

    var entryList: String {
        CoachMemoryLogic.entryList(items: memories)
    }

    /// The compiler's list: every file is represented before Recent can crowd it.
    var compilerEntryList: String {
        CoachMemoryLogic.compilerEntryList(items: memories)
    }

    /// Applies the review pass. Every operation is logged and undoable; stated
    /// notes are only ever refiled or dated, never reworded into something else.
    @discardableResult
    func applyReview(_ operations: [CoachFileReviewOperation], now: Date = Date()) -> [CoachMemoryChange] {
        var applied: [CoachMemoryChange] = []
        let live = effectiveMemories
        func target(_ prefix: String) -> CoachMemoryItem? {
            live.first { $0.id.uuidString.lowercased().hasPrefix(prefix) }
        }
        for operation in operations.prefix(6) {
            switch operation.kind {
            case .refile:
                guard let item = target(operation.idPrefix), let section = operation.section, item.section != section else { continue }
                var moved = item
                moved.category = CoachMemoryCategory(section: section)
                upsert(moved)
                applied.append(record(CoachMemoryChange(
                    kind: .refiled,
                    section: section,
                    itemId: item.id,
                    previousContent: item.section.rawValue,
                    newContent: item.content,
                    createdAt: now
                )))
            case .update:
                guard let item = target(operation.idPrefix) else { continue }
                let before = CoachMemoryFingerprint.normalize(item.content)
                let after = CoachMemoryFingerprint.normalize(operation.text)
                guard before != after else { continue }
                // A stated note may only gain a date or a merged detail, never shrink.
                if item.provenance.isStated, operation.text.count < item.content.count { continue }
                var replacement = CoachMemoryItem(
                    category: item.category,
                    content: operation.text,
                    provenance: item.provenance,
                    createdAt: item.createdAt,
                    lastConfirmedAt: item.lastConfirmedAt,
                    associatedGoalId: item.associatedGoalId,
                    confirmation: item.confirmation,
                    isTemporary: item.isTemporary
                )
                if let section = operation.section { replacement.category = CoachMemoryCategory(section: section) }
                var previous = item
                previous.supersededById = replacement.id
                upsert(previous)
                upsert(replacement)
                applied.append(record(CoachMemoryChange(
                    kind: .updated,
                    section: replacement.section,
                    itemId: replacement.id,
                    previousItemId: item.id,
                    previousContent: item.content,
                    newContent: operation.text,
                    createdAt: now
                )))
            case .retire:
                guard let item = target(operation.idPrefix), !item.provenance.isStated || item.section == .recent else { continue }
                var deleted = item
                deleted.isDeleted = true
                upsert(deleted)
                applied.append(record(CoachMemoryChange(
                    kind: .removed,
                    section: item.section,
                    itemId: item.id,
                    previousContent: item.content,
                    createdAt: now
                )))
            case .add:
                guard let section = operation.section,
                      !CoachMemoryLogic.hasEquivalent(operation.text, in: memories, at: now),
                      !CoachMemoryLogic.isTombstoned(content: operation.text, tombstones: tombstones) else { continue }
                let item = CoachMemoryItem(
                    category: CoachMemoryCategory(section: section),
                    content: operation.text,
                    provenance: .coachNoted,
                    createdAt: now,
                    confirmation: .unconfirmed
                )
                upsert(item)
                applied.append(record(CoachMemoryChange(
                    kind: .added,
                    section: section,
                    itemId: item.id,
                    newContent: operation.text,
                    createdAt: now
                )))
            }
        }
        if !applied.isEmpty {
            persistDerivedProfile()
            reload()
        }
        return applied
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

    /// A note the person typed themselves.
    func addNote(section: CoachMemorySection, content: String) {
        let text = CoachMemoryUpdate.cleaned(content)
        guard !text.isEmpty else { return }
        let item = CoachMemoryItem(
            category: CoachMemoryCategory(section: section),
            content: text,
            provenance: .userStated,
            createdAt: Date(),
            lastConfirmedAt: Date(),
            confirmation: .confirmed
        )
        save(item)
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
            content: CoachMemoryUpdate.cleaned(content),
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

    func recordFeedback(target: String, useful: Bool, goalId: UUID? = nil) {
        modelContext.insert(CoachLocalFeedbackEntity(target: target, useful: useful, goalId: goalId))
        try? modelContext.save()
    }

    /// Chats, files, and the card. Health records and SMART goals are untouched.
    func clearAllMemory() {
        let messages = (try? modelContext.fetch(FetchDescriptor<CoachChatMessageEntity>())) ?? []
        for message in messages { modelContext.delete(message) }
        let states = (try? modelContext.fetch(FetchDescriptor<CoachMemoryStateEntity>())) ?? []
        for state in states { modelContext.delete(state) }
        let items = (try? modelContext.fetch(FetchDescriptor<CoachMemoryItemEntity>())) ?? []
        for item in items { modelContext.delete(item) }
        let threadRows = (try? modelContext.fetch(FetchDescriptor<CoachThreadEntity>())) ?? []
        for row in threadRows { modelContext.delete(row) }
        let changeRows = (try? modelContext.fetch(FetchDescriptor<CoachMemoryChangeEntity>())) ?? []
        for row in changeRows { modelContext.delete(row) }
        try? modelContext.save()
        turns = []
        allTurns = []
        threads = []
        changes = []
        openThreadID = nil
        pendingSeed = nil
        runningSummary = ""
        profile = CoachUserProfile()
        memories = []
        memoryRevision = 0
        cachedCheckIn = nil
        cachedCheckInKey = ""
    }

    // MARK: - Private: chats

    private func seedTurnID(index: Int) -> UUID {
        UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", index)) ?? UUID()
    }

    private func shortDate(_ dateKey: String) -> String {
        guard let date = DateHelpers.date(from: dateKey) else { return dateKey }
        return date.formatted(.dateTime.weekday(.abbreviated))
    }

    private func createThread(from seed: CoachThreadSeed, firstUserText: String?, at date: Date) -> UUID {
        let title: String
        if !seed.provisionalTitle.isEmpty {
            title = seed.provisionalTitle
        } else if let firstUserText {
            title = CoachThreadLogic.provisionalTitle(from: firstUserText)
        } else {
            title = "New chat"
        }
        let openerStart = date.addingTimeInterval(-Double(seed.coachOpeners.count))
        var thread = CoachThread(
            pillar: seed.pillar,
            kind: seed.kind,
            title: title,
            titleIsProvisional: true,
            createdAt: openerStart,
            updatedAt: date,
            lastMessageAt: date,
            contextNote: seed.contextNote,
            goalId: seed.goalId
        )
        for (index, opener) in seed.coachOpeners.enumerated() {
            let turn = CoachChatTurn(
                role: .coach,
                text: opener,
                createdAt: openerStart.addingTimeInterval(Double(index)),
                threadId: thread.id
            )
            modelContext.insert(CoachChatMessageEntity(turn: turn))
            thread.messageCount += 1
            thread.preview = CoachThreadLogic.preview(from: opener)
        }
        modelContext.insert(CoachThreadEntity(thread: thread))
        try? modelContext.save()
        threads.append(thread)
        if seed.linksCheckIn, var checkIn = cachedCheckIn {
            checkIn.replyThreadID = thread.id
            writeCheckIn(checkIn, key: cachedCheckInKey)
        }
        return thread.id
    }

    private func touchThread(_ threadID: UUID, with turn: CoachChatTurn) {
        guard var thread = threads.first(where: { $0.id == threadID }) else { return }
        thread.lastMessageAt = max(turn.createdAt, thread.lastMessageAt)
        thread.updatedAt = turn.createdAt
        thread.messageCount += 1
        let previewText = turn.text.isEmpty && !turn.photoFileNames.isEmpty ? "Photo" : turn.text
        thread.preview = CoachThreadLogic.preview(from: previewText)
        upsertThread(thread)
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

    /// Build-19 rows have no counts or previews; earlier builds left empty
    /// chats behind. Fill the first, drop the second. Returns the rows kept.
    private func backfillThreadRows(_ entities: [CoachThreadEntity]) -> [CoachThreadEntity] {
        var changed = false
        var kept: [CoachThreadEntity] = []
        for entity in entities {
            guard entity.messageCount == 0 else {
                kept.append(entity)
                continue
            }
            let messages = allTurns.filter { $0.threadId == entity.id }.sorted { $0.createdAt < $1.createdAt }
            if messages.isEmpty {
                modelContext.delete(entity)
                changed = true
                continue
            }
            entity.messageCount = messages.count
            if let last = messages.last {
                entity.preview = CoachThreadLogic.preview(from: last.text)
                entity.lastMessageAt = max(entity.lastMessageAt, last.createdAt)
            }
            entity.titleIsProvisional = true
            changed = true
            kept.append(entity)
        }
        if changed {
            try? modelContext.save()
        }
        return kept
    }

    private func migrateLegacyTurnsIfNeeded() {
        let orphans = allTurns.filter { $0.threadId == nil }
        guard !orphans.isEmpty else { return }
        let existing = ((try? modelContext.fetch(FetchDescriptor<CoachThreadEntity>())) ?? [])
            .map { $0.toThread() }
        let thread: CoachThread
        if let legacy = existing.first(where: { $0.title == "Earlier conversation" }) {
            thread = legacy
        } else {
            let created = CoachThread(
                title: "Earlier conversation",
                titleIsProvisional: false,
                preview: CoachThreadLogic.preview(from: orphans.last?.text ?? ""),
                messageCount: orphans.count,
                createdAt: orphans.first?.createdAt ?? Date(),
                updatedAt: orphans.last?.createdAt ?? Date(),
                lastMessageAt: orphans.last?.createdAt ?? Date()
            )
            modelContext.insert(CoachThreadEntity(thread: created))
            thread = created
        }
        let messages = (try? modelContext.fetch(FetchDescriptor<CoachChatMessageEntity>())) ?? []
        for message in messages where message.threadId == nil {
            message.threadId = thread.id
        }
        try? modelContext.save()
        allTurns = messages.compactMap { $0.toTurn() }.sorted { $0.createdAt < $1.createdAt }
    }

    // MARK: - Private: memory

    private func writeCheckIn(_ checkIn: CoachCheckIn?, key: String) {
        let state = fetchOrCreateState()
        state.dailyCardDateKey = key
        if let checkIn,
           let data = try? JSONEncoder().encode(checkIn),
           let json = String(data: data, encoding: .utf8) {
            state.dailyCardJSON = json
        } else {
            state.dailyCardJSON = ""
        }
        state.updatedAt = Date()
        try? modelContext.save()
        cachedCheckInKey = key
        cachedCheckIn = checkIn
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

    @discardableResult
    private func record(_ change: CoachMemoryChange) -> CoachMemoryChange {
        modelContext.insert(CoachMemoryChangeEntity(change: change))
        try? modelContext.save()
        changes.insert(change, at: 0)
        return change
    }

    private func upsertChange(_ change: CoachMemoryChange) {
        let id = change.id
        let descriptor = FetchDescriptor<CoachMemoryChangeEntity>(
            predicate: #Predicate { $0.id == id }
        )
        if let existing = try? modelContext.fetch(descriptor).first {
            existing.apply(change)
        } else {
            modelContext.insert(CoachMemoryChangeEntity(change: change))
        }
        try? modelContext.save()
        if let index = changes.firstIndex(where: { $0.id == change.id }) {
            changes[index] = change
        } else {
            changes.insert(change, at: 0)
        }
    }

    private func addTombstone(_ fingerprint: String) {
        var stamps = tombstones
        stamps.insert(fingerprint)
        writeTombstones(stamps)
    }

    private func removeTombstone(_ fingerprint: String) {
        var stamps = tombstones
        stamps.remove(fingerprint)
        writeTombstones(stamps)
    }

    private func writeTombstones(_ stamps: Set<String>) {
        let state = fetchOrCreateState()
        if let data = try? JSONEncoder().encode(Array(stamps).sorted()),
           let json = String(data: data, encoding: .utf8) {
            state.deletedFingerprintsJSON = json
        }
        try? modelContext.save()
    }

    /// A person edited memory by hand: cancel in-flight model output and make
    /// the next Home visit rewrite the card. The card itself stays so its reply
    /// link survives the rewrite.
    private func bumpRevision(removing contents: [String]) {
        let state = fetchOrCreateState()
        state.memoryRevision += 1
        state.runningSummary = CoachMemoryLogic.sanitizeSummary(state.runningSummary, removing: contents)
        state.dailyCardDateKey = ""
        state.updatedAt = Date()
        try? modelContext.save()
        memoryRevision = state.memoryRevision
        runningSummary = state.runningSummary
        cachedCheckInKey = ""
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
