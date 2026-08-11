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
        force: Bool = false
    ) async {
        refreshAvailability()
        let phase = DayPhase.current()
        // Keyed by phase as well as day: a card written at 7am was written when
        // fiber and exercise were still zero, and it should not still be sitting
        // on the dashboard at 9pm.
        let cacheKey = "\(record.date)#\(phase.rawValue)"
        if !force,
           memory.cachedDailyCardDateKey == cacheKey,
           let cached = memory.cachedDailyCard {
            dailyCard = cached
            dailyCardError = nil
            return
        }

        guard availability == .available else {
            dailyCard = nil
            dailyCardError = nil
            return
        }

        isGeneratingDailyCard = true
        dailyCardError = nil
        defer { isGeneratingDailyCard = false }

        do {
            let snapshot = CoachSnapshotBuilder.build(
                today: record,
                records: records,
                goals: goals,
                hrvSensitivity: hrvSensitivity,
                phase: phase
            )
            let card = try await model.generateDailyCard(
                snapshot: snapshot,
                profile: memory.profile,
                summary: memory.runningSummary
            )
            memory.saveDailyCard(card, dateKey: cacheKey)
            dailyCard = card
        } catch {
            dailyCardError = error.localizedDescription
        }
    }

    func sendChatMessage(
        _ text: String,
        todayRecord: DailyRecord?,
        records: [DailyRecord],
        goals: [SMARTGoal] = [],
        hrvSensitivity: HRVSensitivity = .balanced
    ) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        // Acute risk is answered deterministically, before availability or the model.
        if case .escalate(let message) = CoachSafetyGate.evaluate(trimmed) {
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
        chatError = nil
        defer { isChatBusy = false }

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
            let historyBlock = CoachHistoryResolver.block(
                message: trimmed,
                records: records,
                todayKey: todayRecord?.date ?? DateHelpers.localDateKey(),
                characterBudget: CoachContextBudget.maxHistoryCharacters
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
                recentTurns: memory.recentTurnsForPrompt(limit: CoachContextBudget.maxTranscriptTurns)
            )
            memory.append(CoachChatTurn(role: .coach, text: result.message))
            if let profileUpdate = result.profileUpdate {
                memory.mergeProfile(profileUpdate)
            }
            await refreshSummaryQuietly()
        } catch {
            chatError = error.localizedDescription
        }
    }

    func clearMemory() {
        memory.clearAllMemory()
        dailyCard = nil
        dailyCardError = nil
        chatError = nil
    }

    private func refreshSummaryQuietly() async {
        let turns = memory.recentTurnsForPrompt(limit: 12)
        guard turns.count >= 2 else { return }
        do {
            let summary = try await model.refreshRunningSummary(
                previousSummary: memory.runningSummary,
                recentTurns: turns
            )
            if !summary.isEmpty {
                memory.replaceSummary(summary)
            }
        } catch {
            // Summary refresh is best-effort; chat reply already succeeded.
        }
    }
}
