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
    @Published private(set) var cachedDailyCard: DailyCoachCardContent?
    @Published private(set) var cachedDailyCardDateKey: String = ""

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        reload()
    }

    func reload() {
        let messageDescriptor = FetchDescriptor<CoachChatMessageEntity>(
            sortBy: [SortDescriptor(\.createdAt, order: .forward)]
        )
        let entities = (try? modelContext.fetch(messageDescriptor)) ?? []
        turns = entities.compactMap { $0.toTurn() }

        let state = fetchOrCreateState()
        runningSummary = state.runningSummary
        cachedDailyCardDateKey = state.dailyCardDateKey
        if let data = state.profileJSON.data(using: .utf8),
           let decoded = try? JSONDecoder().decode(CoachUserProfile.self, from: data) {
            profile = decoded
        } else {
            profile = CoachUserProfile()
        }
        if let data = state.dailyCardJSON.data(using: .utf8),
           let card = try? JSONDecoder().decode(DailyCoachCardContent.self, from: data) {
            cachedDailyCard = card
        } else {
            cachedDailyCard = nil
        }
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

    func mergeProfile(_ incoming: CoachUserProfile) {
        var merged = profile
        merged.merge(from: incoming)
        updateProfile(merged)
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

    func clearAllMemory() {
        let messages = (try? modelContext.fetch(FetchDescriptor<CoachChatMessageEntity>())) ?? []
        for message in messages {
            modelContext.delete(message)
        }
        let states = (try? modelContext.fetch(FetchDescriptor<CoachMemoryStateEntity>())) ?? []
        for state in states {
            modelContext.delete(state)
        }
        try? modelContext.save()
        turns = []
        runningSummary = ""
        profile = CoachUserProfile()
        cachedDailyCard = nil
        cachedDailyCardDateKey = ""
    }

    func recentTurnsForPrompt(limit: Int = CoachMemoryStore.recentTurnLimit) -> [CoachChatTurn] {
        Array(turns.suffix(limit))
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
