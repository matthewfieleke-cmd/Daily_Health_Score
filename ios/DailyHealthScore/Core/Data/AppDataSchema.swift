import Foundation
import SwiftData

enum AppDataSchema {
    static let models: [any PersistentModel.Type] = [
        DailyRecordEntity.self,
        SMARTGoalEntity.self,
        SMARTGoalActivityEntity.self,
        CoachChatMessageEntity.self,
        CoachMemoryStateEntity.self,
        CoachMemoryItemEntity.self,
        CoachFollowThroughStateEntity.self,
        CoachLocalFeedbackEntity.self
    ]

    nonisolated static func makeContainer(inMemory: Bool = false) -> ModelContainer {
        do {
            let schema = Schema(models)
            if inMemory {
                return try ModelContainer(
                    for: schema,
                    configurations: ModelConfiguration(isStoredInMemoryOnly: true)
                )
            }
            return try ModelContainer(for: schema)
        } catch {
            fatalError("SwiftData container failed: \(error)")
        }
    }
}

enum SMARTGoalSchema {
    static let defaultsKey = "dhs.smartGoals.schemaVersion"
    static let currentVersion = 2
}
