import Combine
import Foundation
import SwiftData

/// Coordinates availability, the Home check-in, chat, and the memory files.
@MainActor
final class LifestyleCoachController: ObservableObject {
    let memory: CoachMemoryStore
    private let model: FoundationModelsCoach
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
        force: Bool = false,
        now: Date = Date(),
        calendar: Calendar = .current
    ) async {
        refreshAvailability()
        let kind = CoachCheckInLogic.kind(for: now, calendar: calendar)
        let key = CoachCheckInLogic.cacheKey(dateKey: record.date, kind: kind, goals: goals)
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

        guard availability == .available else {
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

        do {
            let snapshot = CoachSnapshotBuilder.build(
                today: record,
                records: records,
                goals: goals,
                hrvSensitivity: hrvSensitivity,
                phase: DayPhase.current(from: now, calendar: calendar),
                now: now,
                calendar: calendar
            )
            let generated = try await model.generateCheckIn(
                kind: kind,
                snapshot: snapshot,
                memoryBlock: memory.promptMemoryBlock,
                recentConversations: memory.recentConversationsBlock(now: now),
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
        activities: [SMARTGoalActivity] = []
    ) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if !isChatBusy {
            beginChatSend()
        }
        let generationID = chatGenerationID

        // Acute risk is answered deterministically, before availability or the model.
        if case .escalate(let message) = CoachSafetyGate.evaluate(trimmed) {
            goalProposal = nil
            pendingGoalCheckIn = nil
            memory.append(CoachChatTurn(role: .user, text: trimmed))
            memory.append(CoachChatTurn(role: .coach, text: message))
            chatError = nil
            if chatGenerationID == generationID { isChatBusy = false }
            return
        }

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
        // Past-day questions are resolved and compared in Swift, so the model
        // never does date arithmetic.
        let historyBlock = focusHistoryBlock(
            message: trimmed,
            records: records,
            todayKey: todayKey,
            focus: focus
        )
        let intent = CoachIntentClassifier.classify(trimmed, hasHistoryReference: historyBlock != nil)
        let allowHealth = CoachThreadLogic.shouldMentionHealth(
            pillar: thread.pillar,
            alreadyMentionedInWindow: memory.hasMentionedHealthThisWindow(),
            userAskedAboutNumbers: intent.usesFullMetrics
        )
        let context = CoachReplyContext(
            thread: thread,
            isFirstReply: isFirstReply,
            pillar: thread.pillar,
            allowUnpromptedHealth: allowHealth,
            recentConversations: memory.recentConversationsBlock(),
            goalPaceDirective: SMARTGoalPace.directive(goals: goals)
        )

        do {
            let snapshot = todayRecord.map {
                CoachSnapshotBuilder.build(
                    today: $0,
                    records: records,
                    goals: goals,
                    hrvSensitivity: hrvSensitivity
                )
            }
            let result = try await model.reply(
                to: trimmed,
                intent: intent,
                snapshot: snapshot,
                historyBlock: historyBlock,
                memoryBlock: memory.promptMemoryBlock,
                recentTurns: memory.recentTurnsForPrompt(limit: CoachContextBudget.maxTranscriptTurns),
                goals: goals,
                focusedGoalID: focusedGoalID ?? thread.goalId,
                previousProposal: goalProposal,
                planningGoal: planningGoal,
                focus: focus,
                activitiesByGoal: Dictionary(grouping: activities, by: \.goalId),
                context: context
            )
            guard chatGenerationID == generationID else { return }
            memory.append(CoachChatTurn(role: .coach, text: result.message))
            memory.applyReplyMetadata(
                threadID: thread.id,
                title: result.title,
                summary: result.summary,
                pillar: result.pillar
            )
            if allowHealth {
                memory.markHealthMentioned()
            }
            goalProposal = result.goalProposal
            pendingGoalCheckIn = result.goalCheckIn
            if result.proposalRejected {
                chatError = "The draft needs clarification before it can be saved. Ask the coach to clarify the action, target, or deadline, or create the goal manually."
            }
            if memory.memoryRevision == memoryRevisionAtStart {
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
        } catch {
            guard chatGenerationID == generationID else { return }
            let message = error.localizedDescription.isEmpty
                ? FoundationModelsCoach.friendlyFailureMessage
                : error.localizedDescription
            chatError = message
            memory.append(CoachChatTurn(role: .coach, text: message))
        }
    }

    /// Call from the UI before the async send so a second chip tap cannot start
    /// another generation and invalidate this one.
    func beginChatSend() {
        isChatBusy = true
        chatGenerationID = UUID()
    }

    /// Chats, files, and the card.
    func clearMemory() {
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

    private func focusHistoryBlock(
        message: String,
        records: [DailyRecord],
        todayKey: String,
        focus: CoachFocusContext?
    ) -> String? {
        if let focus, focus.isHistorical {
            var parts = [focus.promptBlock]
            if let start = focus.startDateKey, let end = focus.endDateKey, start != end {
                let keys = records.map(\.date).filter { $0 >= start && $0 <= end }
                if let range = CoachHistoryResolver.blockForDateKeys(
                    keys,
                    records: records,
                    characterBudget: CoachContextBudget.maxHistoryCharacters
                ) {
                    parts.append(range)
                }
            } else if let start = focus.startDateKey {
                if let day = CoachHistoryResolver.blockForDateKeys(
                    [start],
                    records: records,
                    characterBudget: CoachContextBudget.maxHistoryCharacters
                ) {
                    parts.append(day)
                }
            }
            return parts.joined(separator: "\n")
        }
        return CoachHistoryResolver.block(
            message: message,
            records: records,
            todayKey: todayKey,
            characterBudget: CoachContextBudget.maxHistoryCharacters
        )
    }
}
