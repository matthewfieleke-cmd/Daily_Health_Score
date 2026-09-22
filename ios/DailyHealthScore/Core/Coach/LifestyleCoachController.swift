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

        let trend = kind == .morning && CoachCheckInLogic.isMonday(now, calendar: calendar)
            ? CoachTrendDigest.build(records: records, goals: goals, activities: activities, now: now, calendar: calendar)
            : nil
        let rows = CoachCheckInLogic.goalRows(goals: goals, activities: activities, todayKey: record.date)

        // Nothing has synced for today: a written card would describe an empty
        // day as a bad one. Show the waiting note under a key that never
        // matches, so the first real numbers trigger the write.
        guard CoachCheckInLogic.hasData(record), availability == .available else {
            let fallback = carryingReplyLink(
                HomeCoachCardCopy.fallbackCheckIn(for: record, kind: kind, trend: trend, now: now, calendar: calendar)
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

        await compileProfileIfNeeded()

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
            let generated = try await model.generateCheckIn(
                kind: kind,
                snapshot: snapshot,
                profile: memory.compiledProfile,
                goalRows: rows,
                trend: trend,
                goalPaceDirective: SMARTGoalPace.directive(goals: goals, now: now, calendar: calendar),
                now: now
            )
            guard checkInGenerationID == generationID else { return }
            let fresh = carryingReplyLink(generated)
            memory.saveCheckIn(fresh, key: key)
            checkIn = fresh
        } catch {
            guard checkInGenerationID == generationID else { return }
            let fallback = carryingReplyLink(
                HomeCoachCardCopy.fallbackCheckIn(for: record, kind: kind, trend: trend, now: now, calendar: calendar)
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
        guard !trimmed.isEmpty else { return }
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
            memory.append(CoachChatTurn(role: .user, text: trimmed))
            memory.append(CoachChatTurn(role: .coach, text: message))
            chatError = nil
            if chatGenerationID == generationID { isChatBusy = false }
            return
        }
        var safetyConcern: CoachSafetyGate.Concern?
        if case .concern(let concern) = disposition { safetyConcern = concern }

        refreshAvailability()
        guard availability == .available else {
            chatError = availability.guidance
            if chatGenerationID == generationID { isChatBusy = false }
            return
        }

        let memoryRevisionAtStart = memory.memoryRevision
        chatError = nil
        pendingGoalCheckIn = nil
        defer { if chatGenerationID == generationID { isChatBusy = false } }

        let isFirstReply = !memory.turns.contains { $0.role == .user }
        memory.append(CoachChatTurn(role: .user, text: trimmed))
        guard let thread = memory.openThread else { return }

        let todayKey = todayRecord?.date ?? DateHelpers.localDateKey()
        let context = CoachReplyContext(
            thread: thread,
            isFirstReply: isFirstReply,
            emptyMemorySections: memory.emptySectionLabels
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
            await fileChat(threadID: thread.id, userMessage: trimmed, reply: result.message)
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

    /// Rebuilds the compiled profile when the entries changed. On-device.
    func compileProfileIfNeeded() async {
        guard availability == .available, memory.needsProfileCompile else { return }
        do {
            let profile = try await model.compileProfile(entryList: memory.entryList)
            memory.saveCompiledProfile(profile)
        } catch {
            // The card can be written without a compiled profile; the files stay in the tool.
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
        todayRecord: DailyRecord?,
        records: [DailyRecord],
        goals: [SMARTGoal],
        activities: [SMARTGoalActivity],
        hrvSensitivity: HRVSensitivity,
        bodyTrend: BodyTrend?
    ) async -> CoachEvalResult {
        refreshAvailability()
        let started = Date()
        guard availability == .available else {
            return CoachEvalResult(
                promptID: promptID, reply: "", tier: .onDevice, shape: .general, memoryNotes: [],
                seconds: 0, error: availability.guidance
            )
        }
        let context = CoachReplyContext(thread: nil, isFirstReply: true, emptyMemorySections: memory.emptySectionLabels)
        do {
            // A throwaway turn: the tools see the real app state, nothing is saved.
            live.snapshot = todayRecord.map {
                CoachSnapshotBuilder.build(
                    today: $0, records: records, goals: goals, hrvSensitivity: hrvSensitivity, bodyTrend: bodyTrend
                )
            }
            live.records = records
            live.todayKey = todayRecord?.date ?? DateHelpers.localDateKey()
            live.goals = goals
            live.activitiesByGoal = Dictionary(grouping: activities, by: \.goalId)
            live.memoryItems = memory.effectiveMemories
            live.recentConversations = memory.recentConversationsBlock()
            live.bodyTrend = bodyTrend
            live.focusedGoalID = nil
            live.personsWords = prompt
            let result = try await model.reply(
                to: prompt,
                recentTurns: [],
                live: live,
                context: context
            )
            let notes = result.memoryUpdates.map { update in
                "\(update.operation.rawValue) · \(update.section.label) · \(update.basis.rawValue): \(update.text.isEmpty ? update.replaces : update.text)"
            }
            let draft = result.goalProposal.map { proposal in
                "\(proposal.isUpdate ? "update" : "create"): \(proposal.edit.specificText) × \(proposal.edit.targetCount)"
            }
            return CoachEvalResult(
                promptID: promptID,
                reply: result.message,
                tier: result.tier,
                shape: result.shape,
                memoryNotes: notes,
                seconds: Date().timeIntervalSince(started),
                fallbackReason: result.fallbackReason,
                draft: draft ?? (result.proposalRejected ? "rejected (needs clarification)" : nil),
                toolsUsed: result.toolsUsed
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
