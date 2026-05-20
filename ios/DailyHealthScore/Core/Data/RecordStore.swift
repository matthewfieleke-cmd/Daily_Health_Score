import Foundation
import SwiftData

@MainActor
final class RecordStore: ObservableObject {
    private let modelContext: ModelContext
    @Published private(set) var records: [DailyRecord] = []

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        reload()
    }

    static func makeContainer() -> ModelContainer {
        do {
            return try ModelContainer(for: DailyRecordEntity.self)
        } catch {
            fatalError("SwiftData container failed: \(error)")
        }
    }

    func reload() {
        let descriptor = FetchDescriptor<DailyRecordEntity>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        let entities = (try? modelContext.fetch(descriptor)) ?? []
        records = entities.map { $0.toDailyRecord() }
    }

    func save(_ record: DailyRecord) {
        let descriptor = FetchDescriptor<DailyRecordEntity>(
            predicate: #Predicate { $0.date == record.date }
        )
        if let existing = try? modelContext.fetch(descriptor).first {
            var merged = record
            merged = DailyRecord(
                date: record.date,
                sleepHours: record.sleepHours,
                fiberGrams: record.fiberGrams,
                exerciseMinutes: record.exerciseMinutes,
                sleepGoal: record.sleepGoal,
                fiberGoal: record.fiberGoal,
                sleepScore: record.sleepScore,
                fiberScore: record.fiberScore,
                exerciseScore: record.exerciseScore,
                totalScore: record.totalScore,
                sleepPercent: record.sleepPercent,
                fiberPercent: record.fiberPercent,
                exercisePercent: record.exercisePercent,
                primaryFocus: record.primaryFocus,
                suggestion: record.suggestion,
                createdAt: existing.createdAt,
                updatedAt: record.updatedAt
            )
            existing.apply(merged)
        } else {
            modelContext.insert(DailyRecordEntity(record: record))
        }
        trimRetention()
        try? modelContext.save()
        reload()
    }

    func deleteAll() {
        let all = try? modelContext.fetch(FetchDescriptor<DailyRecordEntity>())
        all?.forEach { modelContext.delete($0) }
        try? modelContext.save()
        reload()
    }

    func exportJSON() -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(records),
              let text = String(data: data, encoding: .utf8) else {
            return "[]"
        }
        return text
    }

    private func trimRetention() {
        let descriptor = FetchDescriptor<DailyRecordEntity>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        guard let all = try? modelContext.fetch(descriptor),
              all.count > DateHelpers.retentionDays else { return }
        for entity in all.dropFirst(DateHelpers.retentionDays) {
            modelContext.delete(entity)
        }
    }
}
