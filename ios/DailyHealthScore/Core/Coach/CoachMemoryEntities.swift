import Foundation
import SwiftData

@Model
final class CoachChatMessageEntity {
    var id: UUID
    var roleRaw: String
    var text: String
    var createdAt: Date

    init(turn: CoachChatTurn) {
        id = turn.id
        roleRaw = turn.role.rawValue
        text = turn.text
        createdAt = turn.createdAt
    }

    func toTurn() -> CoachChatTurn? {
        guard let role = CoachChatTurn.Role(rawValue: roleRaw) else { return nil }
        return CoachChatTurn(id: id, role: role, text: text, createdAt: createdAt)
    }
}

@Model
final class CoachMemoryStateEntity {
    var id: String
    var runningSummary: String
    var profileJSON: String
    var dailyCardDateKey: String
    var dailyCardJSON: String
    var updatedAt: Date

    init(
        id: String = "default",
        runningSummary: String = "",
        profileJSON: String = "",
        dailyCardDateKey: String = "",
        dailyCardJSON: String = "",
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.runningSummary = runningSummary
        self.profileJSON = profileJSON
        self.dailyCardDateKey = dailyCardDateKey
        self.dailyCardJSON = dailyCardJSON
        self.updatedAt = updatedAt
    }
}
