import Combine
import Foundation
import SwiftData

/// Coordinates availability, the Home check-in, chat, and the memory files.
@MainActor
final class LifestyleCoachController: ObservableObject {
    let memory: CoachMemoryStore
    private let model: FoundationModelsCoach
    /// What the Coach's tools read during a reply, and where its actions land.
    private let live = CoachLiveContext()
    private var cancellables = Set<AnyCancellable>()

    @Published private(set) var availability: CoachAvailabilityStatus = .unavailable
    @Published private(set) var checkIn: CoachCheckIn?
    @Published private(set) var isGeneratingCheckIn = false
    @Published private(set) var checkInError: String?
    @Published var isChatBusy = false
    @Published var chatError: String?
    @Published private(set) var goalProposal: CoachGoalProposal?
    /// The Coach heard "I did it"; the person confirms before anything is logged.
    @Published private(set) var pendingGoalCheckIn: CoachGoalCheckInRequest?
    @Published private(set) var isHousekeeping = false
    private var checkInGenerationID = UUID()
    private var chatGenerationID = UUID()
    /// One on-device background compile at a time. A second caller waits,
    /// then compiles again only if the notes moved while the first one ran.
    private var profileCompileFlight: ProfileCompileFlight?

    private struct ProfileCompileFlight {
        var id: UUID
        var key: String
        var task: Task<Void, Never>
    }

    /// Goals changed: re-evaluate the card on the next Home visit without
    /// dropping what is on screen. The cache key ignores progress, so a Done
    /// tap on the card never costs a rewrite.
    func invalidateCheckIn() {
        checkInGenerationID = UUID()
        isGeneratingCheckIn = false
    }

    func dismissGoalProposal() { goalProposal = nil }

    func dismissGoalCheckIn() { pendingGoalCheckIn = nil }

    func recordGoalSaved(_ goal: SMARTGoal) {
        goalProposal = nil
        memory.append(CoachChatTurn(role: .coach, text:
            "Saved your SMART goal: \(goal.generatedSummary) Your \(goal.filledCount) recorded check-ins are preserved."
        ))
    }

    /// Logs the check-in the Coach heard, then says so in the chat.
    func confirmGoalCheckIn(_ request: CoachGoalCheckInRequest, goals: SMARTGoalStore) {
        let logged = goals.recordCheckIn(
            goalId: request.goalId,
            source: .iPhone,
            occurredAt: request.occurredAt,
            note: request.note
        )
        pendingGoalCheckIn = nil
        guard logged, let goal = goals.goals.first(where: { $0.id == request.goalId }) else { return }
        let title = goal.specificText.trimmingCharacters(in: .whitespacesAndNewlines)
        memory.append(CoachChatTurn(
            role: .coach,
            text: "Logged — **\(goal.filledCount) of \(goal.targetCount)** for “\(title)”."
        ))
    }

    init(modelContext: ModelContext, model: FoundationModelsCoach? = nil) {
        self.memory = CoachMemoryStore(modelContext: modelContext)
        // Construct on the main actor here — default args are nonisolated and cannot
        // call `@MainActor` `FoundationModelsCoach.init()`.
        self.model = model ?? FoundationModelsCoach()
        memory.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
        refreshAvailability()
        checkIn = memory.cachedCheckIn
    }

    func refreshAvailability() {
        availability = model.availability
    }

    // MARK: - Home check-in

    func ensureCheckIn(
        for record: DailyRecord,
        records: [DailyRecord],
        goals: [SMARTGoal] = [],
        activities: [SMARTGoalActivity] = [],
        hrvSensitivity: HRVSensitivity = .balanced,
        bodyTrend: BodyTrend? = nil,
        force: Bool = false,
        now: Date = Date(),
        calendar: Calendar = .current
    ) async {
        refreshAvailability()
        let kind = CoachCheckInLogic.kind(for: now, calendar: calendar)
        let key = CoachCheckInLogic.cacheKey(
            dateKey: record.date,
            kind: kind,
            goals: goals,
            signature: CoachCheckInLogic.statusSignature(for: record)
        )
        if !force,
           memory.cachedCheckInKey == key,
           let cached = memory.cachedCheckIn,
           cached.kind == kind,
           cached.dateKey == record.date {
            checkIn = cached
            checkInError = nil
            return
        }

        let rows = CoachCheckInLogic.goalRows(goals: goals, activities: activities, todayKey: record.date)

        // Nothing has synced for today: a written card would describe an empty
        // day as a bad one. Show the waiting note under a key that never
        // matches, so the first real numbers trigger the write.
        guard CoachCheckInLogic.hasData(record), availability == .available else {
            let fallback = carryingReplyLink(
                HomeCoachCardCopy.fallbackCheckIn(for: record, kind: kind, now: now)
            )
            // A fallback is saved so Reply can quote it, under a key that never
            // matches: the next visit tries the model again.
            memory.saveCheckIn(fallback, key: key + "#fallback")
            checkIn = fallback
            checkInError = nil
            return
        }

        isGeneratingCheckIn = true
        let generationID = UUID()
        checkInGenerationID = generationID
        checkInError = nil
        if memory.cachedCheckIn?.kind != kind || memory.cachedCheckIn?.dateKey != record.date {
            // A morning card must not sit on Home while the evening one generates.
            checkIn = nil
        }
        defer { if checkInGenerationID == generationID { isGeneratingCheckIn = false } }

        do {
            let snapshot = CoachSnapshotBuilder.build(
                today: record,
                records: records,
                goals: goals,
                hrvSensitivity: hrvSensitivity,
                phase: DayPhase.current(from: now, calendar: calendar),
                now: now,
                calendar: calendar,
                bodyTrend: bodyTrend
            )
            let trend = CoachTrendDigest.build(
                records: records,
                goals: goals,
                activities: activities,
                now: now,
                calendar: calendar
            )
            let generated = try await model.generateCheckIn(
                kind: kind,
                snapshot: snapshot,
                goalRows: rows,
                trend: trend,
                paceFacts: SMARTGoalPace.paceFacts(goals: goals, now: now, calendar: calendar),
                notes: CoachMemoryLogic.cardNotes(
                    items: memory.effectiveMemories,
                    at: now,
                    calendar: calendar
                ),
                now: now
            )
            guard checkInGenerationID == generationID else { return }
            let fresh = carryingReplyLink(generated)
            memory.saveCheckIn(fresh, key: key)
            checkIn = fresh
        } catch {
            guard checkInGenerationID == generationID else { return }
            let fallback = carryingReplyLink(
                HomeCoachCardCopy.fallbackCheckIn(for: record, kind: kind, now: now)
            )
            memory.saveCheckIn(fallback, key: key + "#fallback")
            checkIn = fallback
            checkInError = error.localizedDescription
        }
    }

    /// A rewrite of the same card keeps the chat its Reply already opened.
    private func carryingReplyLink(_ fresh: CoachCheckIn) -> CoachCheckIn {
        var card = fresh
        if let old = memory.cachedCheckIn, old.dateKey == fresh.dateKey, old.kind == fresh.kind {
            card.replyThreadID = old.replyThreadID
        }
        return card
    }

    // MARK: - Chat

    func sendChatMessage(
        _ text: String,
        photoFileNames: [String] = [],
        todayRecord: DailyRecord?,
        records: [DailyRecord],
        goals: [SMARTGoal] = [],
        hrvSensitivity: HRVSensitivity = .balanced,
        focusedGoalID: UUID? = nil,
        planningGoal: Bool = false,
        focus: CoachFocusContext? = nil,
        activities: [SMARTGoalActivity] = [],
        bodyTrend: BodyTrend? = nil
    ) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty || !photoFileNames.isEmpty else { return }
        if !isChatBusy {
            beginChatSend()
        }
        let generationID = chatGenerationID

        // Acute risk is answered deterministically, before availability or the model.
        // A concern short of that rides along so the model answers with care, and so
        // the app can, if the model declines.
        let disposition = CoachSafetyGate.evaluate(trimmed)
        if case .escalate(let message) = disposition {
            goalProposal = nil
            pendingGoalCheckIn = nil
            memory.append(CoachChatTurn(role: .user, text: trimmed, photoFileNames: photoFileNames))
            memory.append(CoachChatTurn(role: .coach, text: message))
            chatError = nil
            if chatGenerationID == generationID { isChatBusy = false }
            return
        }
        var safetyConcern: CoachSafetyGate.Concern?
        if case .concern(let concern) = disposition { safetyConcern = concern }

        refreshAvailability()
        guard availability == .available else {
            CoachPhotoStore.delete(fileNames: photoFileNames)
            chatError = availability.guidance
            if chatGenerationID == generationID { isChatBusy = false }
            return
        }

        let memoryRevisionAtStart = memory.memoryRevision
        chatError = nil
        pendingGoalCheckIn = nil
        defer { if chatGenerationID == generationID { isChatBusy = false } }

        let isFirstReply = !memory.turns.contains { $0.role == .user }
        memory.append(CoachChatTurn(role: .user, text: trimmed, photoFileNames: photoFileNames))
        guard let thread = memory.openThread else { return }

        let todayKey = todayRecord?.date ?? DateHelpers.localDateKey()
        let context = CoachReplyContext(
            thread: thread,
            isFirstReply: isFirstReply
        )

        do {
            // Everything the tools can reach for, live, for this turn.
            live.snapshot = todayRecord.map {
                CoachSnapshotBuilder.build(
                    today: $0,
                    records: records,
                    goals: goals,
                    hrvSensitivity: hrvSensitivity,
                    bodyTrend: bodyTrend
                )
            }
            live.records = records
            live.todayKey = todayKey
            live.goals = goals
            live.activitiesByGoal = Dictionary(grouping: activities, by: \.goalId)
            live.memoryItems = memory.effectiveMemories
            live.recentConversations = memory.recentConversationsBlock()
            live.bodyTrend = bodyTrend
            live.focusedGoalID = focusedGoalID ?? thread.goalId
            live.personsWords = ([trimmed] + memory.turns.filter { $0.role == .user }.suffix(6).map(\.text)).joined(separator: " ")
            _ = planningGoal

            let result = try await model.reply(
                to: trimmed,
                photoFileNames: photoFileNames,
                recentTurns: memory.recentTurnsForPrompt(limit: CoachContextBudget.maxTranscriptTurns),
                live: live,
                focus: focus,
                context: context
            )
            guard chatGenerationID == generationID else { return }
            let reason = result.tier == .onDevice
                ? (result.fallbackReason ?? (CoachModelProvider.isServerQuotaExhausted ? "today’s Private Cloud Compute limit is reached" : nil))
                : nil
            memory.append(CoachChatTurn(role: .coach, text: result.message, modelTier: result.tier, fallbackReason: reason))
            // The reply is on screen; the composer reopens now, while filing
            // and profile work continue on-device behind it.
            isChatBusy = false
            goalProposal = result.goalProposal
            pendingGoalCheckIn = result.goalCheckIn
            if result.proposalRejected {
                chatError = "The draft needs clarification before it can be saved. Ask the coach to clarify the action, target, or deadline, or create the goal manually."
            }
            if memory.memoryRevision == memoryRevisionAtStart {
                // The remember tool already validated and grounded each note.
                let applied = memory.applyCoachUpdates(
                    result.memoryUpdates,
                    threadID: thread.id,
                    generationRevision: memoryRevisionAtStart
                )
                if applied.isEmpty, result.memoryUpdates.isEmpty {
                    // Deterministic safety net when the model kept no notes.
                    memory.ingestUserStatedFacts(from: trimmed)
                }
            }
            // Filing happens after the reply is on screen and costs no quota.
            let filingText = trimmed.isEmpty
                ? (photoFileNames.count > 1 ? "The person sent photos." : "The person sent a photo.")
                : trimmed
            await fileChat(threadID: thread.id, userMessage: filingText, reply: result.message)
            await compileProfileIfNeeded()
        } catch {
            guard chatGenerationID == generationID else { return }
            if let coachError = error as? FoundationModelsCoach.CoachError,
               case .declined(let reason) = coachError {
                // Both models refused the content. The app answers with care,
                // keeps whatever facts the message plainly stated, and names
                // the refusal once, under the reply, so it is never a mystery.
                memory.append(CoachChatTurn(role: .coach, text: CoachSafetyGate.declinedReply(concern: safetyConcern)))
                memory.ingestUserStatedFacts(from: trimmed)
                chatError = "The model declined this message: \(reason)"
                return
            }
            let message = error.localizedDescription.isEmpty
                ? FoundationModelsCoach.friendlyFailureMessage
                : error.localizedDescription
            memory.append(CoachChatTurn(role: .coach, text: message))
            // The bubble carries the words; the line under it carries the cause.
            chatError = model.lastFailureReason.map { "Model error: \($0)" }
        }
    }

    /// Call from the UI before the async send so a second chip tap cannot start
    /// another generation and invalidate this one.
    func beginChatSend() {
        isChatBusy = true
        chatGenerationID = UUID()
    }

    // MARK: - On-device filing and housekeeping

    private func fileChat(threadID: UUID, userMessage: String, reply: String) async {
        guard let thread = memory.threads.first(where: { $0.id == threadID }) else { return }
        do {
            let filing = try await model.fileChat(
                userMessage: userMessage,
                reply: reply,
                currentTitle: thread.title,
                titleIsProvisional: thread.titleIsProvisional,
                currentPillar: thread.pillar
            )
            memory.applyReplyMetadata(
                threadID: threadID,
                title: filing.title,
                summary: filing.summary,
                pillar: filing.pillar
            )
        } catch {
            // The provisional title stands; nothing else depends on this.
        }
    }

    /// Rebuilds the compiled background when the entries changed. On-device.
    /// Callers that overlap — chat, the Home card, the memory screen — share
    /// one compile. A result is stored only for the notes that were compiled.
    func compileProfileIfNeeded() async {
        memory.discardCompiledProfileIfNotesAreGone()
        guard availability == .available else { return }
        defer { memory.discardCompiledProfileIfNotesAreGone() }

        if let current = profileCompileFlight {
            await current.task.value
            let replacement = profileCompileFlight
            if let replacement, replacement.id != current.id {
                await compileProfileIfNeeded()
                return
            }
            if replacement?.id == current.id {
                profileCompileFlight = nil
            }
            // Same notes and a miss: leave it stale and let the next visit try.
            // A newer picture compiles once, below.
            guard memory.memoryFingerprint != current.key, memory.needsProfileCompile else { return }
        }

        guard memory.needsProfileCompile else { return }
        let key = memory.memoryFingerprint
        let entries = memory.compilerEntryList
        let id = UUID()
        let task = Task { @MainActor in
            await self.storeCompiledProfile(entryList: entries, key: key)
        }
        profileCompileFlight = ProfileCompileFlight(id: id, key: key, task: task)
        await task.value
        if profileCompileFlight?.id == id {
            profileCompileFlight = nil
        }
        if memory.memoryFingerprint != key, memory.needsProfileCompile {
            await compileProfileIfNeeded()
        }
    }

    private func storeCompiledProfile(entryList: String, key: String) async {
        do {
            let profile = try await model.compileProfile(entryList: entryList)
            guard let stored = CoachCharter.backgroundToStore(
                compiled: profile,
                sourceUnchanged: memory.memoryFingerprint == key,
                notesAreEmpty: memory.effectiveMemories.isEmpty
            ) else { return }
            memory.saveCompiledProfile(stored)
        } catch {
            // The card and the chat can go out without a background; the files stay in the tool.
        }
    }

    /// Daily tidy of the files, on-device, logged and undoable.
    func performHousekeepingIfDue() async {
        refreshAvailability()
        guard availability == .available, !isHousekeeping, memory.shouldReviewFiles() else { return }
        isHousekeeping = true
        defer { isHousekeeping = false }
        do {
            let operations = try await model.reviewFiles(entryList: memory.entryList)
            memory.applyReview(operations)
            memory.markFilesReviewed()
            await compileProfileIfNeeded()
        } catch {
            // Try again tomorrow.
        }
    }

    // MARK: - Eval

    /// Runs one prompt through the live pipeline without saving anything:
    /// no chat, no memory edits, no card. For the eval screen.
    func evaluate(
        prompt: String,
        promptID: String,
        messages: [String]? = nil,
        forcedTier: CoachModelTier? = nil,
        reasoningDepth: CoachReasoningDepth = .deep,
        todayRecord: DailyRecord?,
        records: [DailyRecord],
        goals: [SMARTGoal],
        activities: [SMARTGoalActivity],
        hrvSensitivity: HRVSensitivity,
        bodyTrend: BodyTrend?
    ) async -> CoachEvalResult {
        refreshAvailability()
        let started = Date()
        let sequence = (messages ?? [prompt])
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard availability == .available else {
            return CoachEvalResult(
                promptID: promptID, reply: "", tier: .onDevice, shape: .general, memoryNotes: [],
                seconds: 0, error: availability.guidance
            )
        }
        guard !sequence.isEmpty else {
            return CoachEvalResult(
                promptID: promptID, reply: "", tier: .onDevice, shape: .general,
                memoryNotes: [], seconds: 0, error: "No eval message."
            )
        }
        let evalThread = sequence.count > 1
            ? CoachThread(title: "Developer Eval", titleIsProvisional: false)
            : nil
        // Eval can outlive its screen while a normal chat opens. Its pending
        // actions and tool traces must never share the production turn bag.
        let evalLive = CoachLiveContext()
        defer {
            if let evalThread {
                model.forgetSession(for: evalThread.id)
            }
        }
        do {
            var turns: [CoachChatTurn] = []
            var transcript: [String] = []
            var notes: [String] = []
            var tools: [String] = []
            var drafts: [String] = []
            var fallbackReasons: [String] = []
            var lastResult: CoachReplyResult?

            for (index, message) in sequence.enumerated() {
                // A throwaway turn: tools see real app state, nothing is saved.
                evalLive.snapshot = todayRecord.map {
                    CoachSnapshotBuilder.build(
                        today: $0,
                        records: records,
                        goals: goals,
                        hrvSensitivity: hrvSensitivity,
                        bodyTrend: bodyTrend
                    )
                }
                evalLive.records = records
                evalLive.todayKey = todayRecord?.date ?? DateHelpers.localDateKey()
                evalLive.goals = goals
                evalLive.activitiesByGoal = Dictionary(grouping: activities, by: \.goalId)
                evalLive.memoryItems = memory.effectiveMemories
                evalLive.recentConversations = memory.recentConversationsBlock()
                evalLive.bodyTrend = bodyTrend
                evalLive.focusedGoalID = nil
                evalLive.personsWords = (
                    [message]
                        + turns.filter { $0.role == .user }.suffix(6).map(\.text)
                ).joined(separator: " ")

                turns.append(CoachChatTurn(role: .user, text: message))
                let context = CoachReplyContext(
                    thread: evalThread,
                    isFirstReply: index == 0
                )
                let result = try await model.reply(
                    to: message,
                    recentTurns: turns,
                    live: evalLive,
                    forcedTier: forcedTier,
                    reasoningDepth: reasoningDepth,
                    context: context
                )
                turns.append(
                    CoachChatTurn(
                        role: .coach,
                        text: result.message,
                        modelTier: result.tier,
                        fallbackReason: result.fallbackReason
                    )
                )
                transcript.append(
                    "Turn \(index + 1) · Coach [\(result.tier.rawValue)]: \(result.message)"
                )
                notes.append(contentsOf: result.memoryUpdates.map { update in
                    let detail = "\(update.operation.rawValue) · \(update.section.label) · \(update.basis.rawValue): \(update.text.isEmpty ? update.replaces : update.text)"
                    return sequence.count == 1 ? detail : "Turn \(index + 1) · \(detail)"
                })
                tools.append(contentsOf: result.toolsUsed.map {
                    sequence.count == 1 ? $0 : "Turn \(index + 1) · \($0)"
                })
                if let proposal = result.goalProposal {
                    let detail = "\(proposal.isUpdate ? "update" : "create"): \(proposal.edit.specificText) × \(proposal.edit.targetCount)"
                    drafts.append(sequence.count == 1 ? detail : "Turn \(index + 1) · \(detail)")
                } else if result.proposalRejected {
                    drafts.append(
                        sequence.count == 1
                            ? "rejected (needs clarification)"
                            : "Turn \(index + 1) · rejected (needs clarification)"
                    )
                }
                if let reason = result.fallbackReason, !reason.isEmpty {
                    fallbackReasons.append("Turn \(index + 1): \(reason)")
                }
                lastResult = result
            }

            guard let result = lastResult else {
                throw FoundationModelsCoach.CoachError.generationFailed("The eval returned no reply.")
            }
            return CoachEvalResult(
                promptID: promptID,
                reply: sequence.count == 1 ? result.message : transcript.joined(separator: "\n\n"),
                tier: result.tier,
                shape: result.shape,
                memoryNotes: notes,
                seconds: Date().timeIntervalSince(started),
                fallbackReason: fallbackReasons.isEmpty
                    ? result.fallbackReason
                    : fallbackReasons.joined(separator: "; "),
                draft: drafts.isEmpty ? nil : drafts.joined(separator: "; "),
                toolsUsed: tools,
                reasoningDepth: result.tier == .onDevice ? .light : reasoningDepth
            )
        } catch {
            let reason = model.lastFailureReason ?? error.localizedDescription
            return CoachEvalResult(
                promptID: promptID, reply: "", tier: .onDevice, shape: .general, memoryNotes: [],
                seconds: Date().timeIntervalSince(started), error: reason
            )
        }
    }

    // MARK: - Clearing

    /// Chats, files, and the card.
    func forgetSession(for threadID: UUID) {
        model.forgetSession(for: threadID)
    }

    func clearMemory() {
        model.forgetAllSessions()
        chatGenerationID = UUID()
        isChatBusy = false
        goalProposal = nil
        pendingGoalCheckIn = nil
        invalidateCheckIn()
        memory.clearAllMemory()
        checkIn = nil
        checkInError = nil
        chatError = nil
    }

    /// Chats only; the memory files stay.
    func deleteAllChats() {
        model.forgetAllSessions()
        chatGenerationID = UUID()
        isChatBusy = false
        goalProposal = nil
        pendingGoalCheckIn = nil
        chatError = nil
        memory.deleteAllChats()
        checkIn = memory.cachedCheckIn
    }

    func recordLocalFeedback(target: String, useful: Bool, goalId: UUID? = nil) {
        memory.recordFeedback(target: target, useful: useful, goalId: goalId)
    }

}
