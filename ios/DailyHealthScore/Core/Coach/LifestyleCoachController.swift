import Combine
import Foundation
import SwiftData

/// Coordinates availability, daily cards, chat, summary, and profile memory.
@MainActor
final class LifestyleCoachController: ObservableObject {
    let memory: CoachMemoryStore
    private let model: FoundationModelsCoach
    private var cancellables = Set<AnyCancellable>()

    @Published private(set) var availability: CoachAvailabilityStatus = .unavailable
    @Published private(set) var dailyCard: DailyCoachCardContent?
    @Published private(set) var isGeneratingDailyCard = false
    @Published private(set) var dailyCardError: String?
    @Published var isChatBusy = false
    @Published var chatError: String?
    @Published private(set) var goalProposal: CoachGoalProposal?
    private var dailyGenerationID = UUID()
    private var chatGenerationID = UUID()

    func invalidateDailyCard() {
        dailyGenerationID = UUID()
        dailyCard = nil
        isGeneratingDailyCard = false
    }

    func dismissGoalProposal() { goalProposal = nil }

    func recordGoalSaved(_ goal: SMARTGoal) {
        goalProposal = nil
        memory.append(CoachChatTurn(role: .coach, text:
            "Saved your SMART goal: \(goal.generatedSummary) Your \(goal.filledCount) recorded check-ins are preserved."
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
        memory.$memoryRevision
            .dropFirst()
            .sink { [weak self] _ in
                guard let self, self.isChatBusy else { return }
                self.chatGenerationID = UUID()
                self.isChatBusy = false
            }
            .store(in: &cancellables)
        refreshAvailability()
        dailyCard = memory.cachedDailyCard
    }

    func refreshAvailability() {
        availability = model.availability
    }

    func ensureDailyCard(
        for record: DailyRecord,
        records: [DailyRecord],
        goals: [SMARTGoal] = [],
        hrvSensitivity: HRVSensitivity = .balanced,
        force: Bool = false,
        now: Date = Date(),
        calendar: Calendar = .current
    ) async {
        refreshAvailability()
        let timeOfDay = CoachTimeOfDay.current(from: now, calendar: calendar)
        // Keyed by clock window as well as day: a morning card must not still
        // sit on Home at 6pm suggesting lunch.
        let cacheKey = "\(record.date)#\(timeOfDay.rawValue)#\(CoachGoalPlanning.cacheKey(goals: goals))"
        if !force,
           memory.cachedDailyCardDateKey == cacheKey,
           let cached = memory.cachedDailyCard {
            dailyCard = cached
            dailyCardError = nil
            return
        }

        guard availability == .available else {
            dailyCard = HomeCoachCardCopy.fallbackCard(for: record, now: now, calendar: calendar)
            dailyCardError = nil
            return
        }

        isGeneratingDailyCard = true
        let generationID = UUID()
        dailyGenerationID = generationID
        dailyCardError = nil
        if memory.cachedDailyCardDateKey != cacheKey {
            // Drop a morning card before the evening rewrite, so Home never
            // keeps showing "after lunch" while the new note generates.
            dailyCard = nil
        }
        defer { if dailyGenerationID == generationID { isGeneratingDailyCard = false } }

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
            let card = try await model.generateDailyCard(
                snapshot: snapshot,
                profile: memory.profile,
                summary: memory.runningSummary,
                memoryBlock: memory.promptMemoryBlock
            )
            guard dailyGenerationID == generationID else { return }
            memory.saveDailyCard(card, dateKey: cacheKey)
            dailyCard = card
        } catch {
            guard dailyGenerationID == generationID else { return }
            dailyCard = HomeCoachCardCopy.fallbackCard(for: record, now: now, calendar: calendar)
            dailyCardError = error.localizedDescription
        }
    }

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
        guard !trimmed.isEmpty, !isChatBusy else { return }

        // Acute risk is answered deterministically, before availability or the model.
        if case .escalate(let message) = CoachSafetyGate.evaluate(trimmed) {
            goalProposal = nil
            memory.append(CoachChatTurn(role: .user, text: trimmed))
            memory.append(CoachChatTurn(role: .coach, text: message))
            chatError = nil
            return
        }

        refreshAvailability()
        guard availability == .available else {
            chatError = availability.guidance
            return
        }

        isChatBusy = true
        let generationID = UUID()
        chatGenerationID = generationID
        let memoryRevisionAtStart = memory.memoryRevision
        chatError = nil
        defer { if chatGenerationID == generationID { isChatBusy = false } }

        memory.append(CoachChatTurn(role: .user, text: trimmed))

        do {
            let snapshot = todayRecord.map {
                CoachSnapshotBuilder.build(
                    today: $0,
                    records: records,
                    goals: goals,
                    hrvSensitivity: hrvSensitivity
                )
            }
            // Past-day questions are resolved and compared in Swift, so the model
            // never does date arithmetic.
            let historyBlock = focusHistoryBlock(
                message: trimmed,
                records: records,
                todayKey: todayRecord?.date ?? DateHelpers.localDateKey(),
                focus: focus
            )
            // Both blocks are built at their ceiling and trimmed by the coach once
            // it knows which model is answering.
            let result = try await model.reply(
                to: trimmed,
                intent: CoachIntentClassifier.classify(
                    trimmed,
                    hasHistoryReference: historyBlock != nil
                ),
                snapshot: snapshot,
                historyBlock: historyBlock,
                profile: memory.profile,
                summary: memory.runningSummary,
                recentTurns: memory.recentTurnsForPrompt(limit: CoachContextBudget.maxTranscriptTurns),
                goals: goals,
                focusedGoalID: focusedGoalID,
                previousProposal: goalProposal,
                planningGoal: planningGoal,
                focus: focus,
                memoryBlock: memory.promptMemoryBlock,
                activitiesByGoal: Dictionary(grouping: activities, by: \.goalId)
            )
            guard chatGenerationID == generationID else { return }
            memory.append(CoachChatTurn(role: .coach, text: result.message))
            goalProposal = result.goalProposal
            if result.proposalRejected {
                chatError = "The draft needs clarification before it can be saved. Ask the coach to clarify the action, target, or deadline, or create the goal manually."
            }
            if memory.memoryRevision == memoryRevisionAtStart, let profileUpdate = result.profileUpdate {
                _ = memory.ingestModelProfileUpdate(profileUpdate, generationRevision: memoryRevisionAtStart)
            }
            if memory.memoryRevision == memoryRevisionAtStart {
                await refreshSummaryQuietly(generationID: generationID, memoryRevision: memoryRevisionAtStart)
            }
        } catch {
            guard chatGenerationID == generationID else { return }
            chatError = error.localizedDescription
        }
    }

    func clearMemory() {
        chatGenerationID = UUID()
        isChatBusy = false
        goalProposal = nil
        invalidateDailyCard()
        memory.clearAllMemory()
        dailyCard = nil
        dailyCardError = nil
        chatError = nil
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

    private func refreshSummaryQuietly(generationID: UUID, memoryRevision: Int) async {
        let turns = memory.recentTurnsForPrompt(limit: 12)
        guard turns.count >= 2 else { return }
        do {
            let summary = try await model.refreshRunningSummary(
                previousSummary: memory.runningSummary,
                recentTurns: turns,
                currentMemory: memory.promptMemoryBlock
            )
            if chatGenerationID == generationID,
               self.memory.memoryRevision == memoryRevision,
               !summary.isEmpty {
                memory.replaceSummary(summary)
            }
        } catch {
            // Summary refresh is best-effort; chat reply already succeeded.
        }
    }
}
