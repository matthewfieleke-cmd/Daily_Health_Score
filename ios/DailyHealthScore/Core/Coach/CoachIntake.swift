import Foundation

/// The baseline form. Each answer becomes one note in the file that matches
/// the question. Private Cloud Compute is not involved: the form does not
/// paraphrase, and it does not become a script in the chat.
enum CoachIntakeField: String, CaseIterable, Identifiable, Codable, Sendable {
    case name
    case work
    case heavyDays
    case household
    case tripsUp
    case enjoys
    case sleep
    case eating
    case movement
    case health
    case coaching

    var id: String { rawValue }

    var title: String {
        switch self {
        case .name: return "What should I call you?"
        case .work: return "What do you do for work?"
        case .heavyDays: return "Which days run heaviest?"
        case .household: return "Who’s at home?"
        case .tripsUp: return "What tends to trip you up?"
        case .enjoys: return "What do you enjoy, or what helps?"
        case .sleep: return "Sleep, if you want this known"
        case .eating: return "How you usually eat, in your words"
        case .movement: return "Movement you already do"
        case .health: return "Conditions, medicines, or limits"
        case .coaching: return "How you want to be coached"
        }
    }

    var placeholder: String {
        switch self {
        case .name: return "Matt"
        case .work: return "Family Medicine"
        case .heavyDays: return "Tuesdays"
        case .household: return "Wife Maureen, sons Isaac and Caleb"
        case .tripsUp: return "Eating after an argument"
        case .enjoys: return "Music, working outside"
        case .sleep: return "In bed by 10, up at 6"
        case .eating: return "Oatmeal most mornings"
        case .movement: return "Walks after clinic"
        case .health: return "Nothing you need to work around"
        case .coaching: return "Direct, and don’t lecture me"
        }
    }

    var section: CoachMemorySection {
        switch self {
        case .name, .work: return .aboutYou
        case .heavyDays, .sleep, .movement: return .routines
        case .household: return .people
        case .tripsUp: return .patterns
        case .enjoys, .eating: return .likes
        case .health: return .body
        case .coaching: return .coaching
        }
    }

    /// Form sections, in the order a person fills them.
    static let groups: [(title: String, fields: [CoachIntakeField])] = [
        ("You", [.name, .work]),
        ("Your week", [.heavyDays, .sleep, .movement]),
        ("People", [.household]),
        ("What gets in the way, and what you reach for", [.tripsUp, .enjoys, .eating]),
        ("If you want this known", [.health, .coaching])
    ]

    /// Their words, labeled so the file shows which question they answered.
    func note(from answer: String) -> String {
        let text = answer.trimmingCharacters(in: .whitespacesAndNewlines)
        switch self {
        case .name: return "Goes by \(text)."
        case .work: return "Work: \(text)."
        case .heavyDays: return "Heaviest days: \(text)."
        case .household: return "At home: \(text)."
        case .tripsUp: return "Gets in the way: \(text)."
        case .enjoys: return "Enjoys: \(text)."
        case .sleep: return "Sleep: \(text)."
        case .eating: return "Eating: \(text)."
        case .movement: return "Movement: \(text)."
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
