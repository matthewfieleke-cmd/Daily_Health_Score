import Foundation

/// The baseline form. Each answer becomes one note in the file that matches
/// the question. Private Cloud Compute is not involved: the form does not
/// paraphrase, and it does not become a script in the chat.
enum CoachIntakeField: String, CaseIterable, Identifiable, Codable, Sendable {
    case name
    case usualDay
    case wantToChange
    case betterLooksLike
    case sleep
    case eating
    case movement
    case household
    case hardestTimes
    case knocksOffTrack
    case health
    case coaching

    var id: String { rawValue }

    var title: String {
        switch self {
        case .name: return "What should I call you?"
        case .usualDay: return "What does a usual day look like?"
        case .wantToChange: return "What do you most want to change?"
        case .betterLooksLike: return "What would better look like for you?"
        case .sleep: return "When do you usually sleep, and what gets in the way?"
        case .eating: return "How do you usually eat?"
        case .movement: return "What movement do you already do, and what do you like?"
        case .household: return "Who is part of your day at home?"
        case .hardestTimes: return "When is it hardest to take care of yourself?"
        case .knocksOffTrack: return "What usually knocks you off track?"
        case .health: return "Conditions, medicines, injuries, or limits I should work around"
        case .coaching: return "How do you want me to talk with you?"
        }
    }

    var section: CoachMemorySection {
        switch self {
        case .name: return .aboutYou
        case .usualDay, .sleep, .movement, .hardestTimes: return .routines
        case .wantToChange, .betterLooksLike: return .goals
        case .household: return .people
        case .knocksOffTrack: return .patterns
        case .eating: return .likes
        case .health: return .body
        case .coaching: return .coaching
        }
    }

    /// One step of the form. A person can skip any question.
    static let groups: [(title: String, detail: String, fields: [CoachIntakeField])] = [
        ("You", "The shape of your days.", [.name, .usualDay]),
        ("What you want", "So the advice has a point.", [.wantToChange, .betterLooksLike]),
        ("Sleep, eating, movement", "What you already do.", [.sleep, .eating, .movement]),
        ("People and hard parts", "The context around the habits.", [.household, .hardestTimes, .knocksOffTrack]),
        ("Before any advice", "What should not be guessed.", [.health, .coaching])
    ]

    /// Their words, labeled so the file shows which question they answered.
    func note(from answer: String) -> String {
        let text = answer.trimmingCharacters(in: .whitespacesAndNewlines)
        switch self {
        case .name: return "Goes by \(text)."
        case .usualDay: return "Usual day: \(text)."
        case .wantToChange: return "Wants to change: \(text)."
        case .betterLooksLike: return "Better looks like: \(text)."
        case .sleep: return "Sleep: \(text)."
        case .eating: return "Eating: \(text)."
        case .movement: return "Movement: \(text)."
        case .household: return "At home: \(text)."
        case .hardestTimes: return "Hardest times: \(text)."
        case .knocksOffTrack: return "Knocks them off track: \(text)."
        case .health: return "Health: \(text)."
        case .coaching: return "Coaching: \(text)."
        }
    }
}

struct CoachIntakeRecord: Codable, Equatable, Sendable {
    var completedAt: Date?
    var answers: [String: String]
    var noteIDs: [String: String]

    static let empty = CoachIntakeRecord(completedAt: nil, answers: [:], noteIDs: [:])
}
