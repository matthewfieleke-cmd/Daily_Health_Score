import Foundation

@MainActor
final class SettingsStore: ObservableObject {
    private enum Keys {
        static let sleepGoal = "dhs.sleepGoal"
        static let fiberGoal = "dhs.fiberGoal"
        static let usedSuggestions = "dhs.usedSuggestions"
        static let usedDiscouragement = "dhs.usedDiscouragement"
        static let usedMotivation = "dhs.usedMotivation"
    }

    @Published var settings: UserSettings {
        didSet { persistSettings() }
    }

    private var usedSuggestions: [String: [String]] = [:]
    private var usedDiscouragement: [String] = []
    private var usedMotivation: [String] = []

    init() {
        let sleepRaw = UserDefaults.standard.double(forKey: Keys.sleepGoal)
        let fiberRaw = UserDefaults.standard.integer(forKey: Keys.fiberGoal)
        let sleep = SleepGoalHours(rawValue: sleepRaw == 0 ? 7.5 : sleepRaw) ?? .sevenHalf
        let fiber = FiberGoalGrams(rawValue: fiberRaw == 0 ? 40 : fiberRaw) ?? .forty
        settings = UserSettings(sleepGoal: sleep, fiberGoal: fiber)
        loadRotationState()
    }

    func nextSuggestion(for focus: PrimaryFocus) -> String {
        let category = focus == .maintain ? "maintain" : focus.rawValue
        let pool = SuggestionLibrary.pool(for: focus)
        var used = usedSuggestions[category] ?? []
        var unused = pool.filter { !used.contains($0.id) }
        if unused.isEmpty {
            used = []
            unused = pool
        }
        let choice = unused[0]
        used.append(choice.id)
        usedSuggestions[category] = used
        persistRotation()
        return choice.text
    }

    func nextDiscouragement() -> String {
        nextFromPool(
            pool: DiscouragementLibrary.all,
            used: &usedDiscouragement,
            key: Keys.usedDiscouragement
        )
    }

    func nextMotivation() -> String {
        nextFromPool(
            pool: MotivationLibrary.all,
            used: &usedMotivation,
            key: Keys.usedMotivation
        )
    }

    func clearRotationState() {
        usedSuggestions = [:]
        usedDiscouragement = []
        usedMotivation = []
        persistRotation()
    }

    private func nextFromPool(
        pool: [ContentEntry],
        used: inout [String],
        key: String
    ) -> String {
        var unused = pool.filter { !used.contains($0.id) }
        if unused.isEmpty {
            used = []
            unused = pool
        }
        let choice = unused[0]
        used.append(choice.id)
        UserDefaults.standard.set(used, forKey: key)
        return choice.text
    }

    private func persistSettings() {
        UserDefaults.standard.set(settings.sleepGoal.rawValue, forKey: Keys.sleepGoal)
        UserDefaults.standard.set(settings.fiberGoal.rawValue, forKey: Keys.fiberGoal)
    }

    private func loadRotationState() {
        usedSuggestions = UserDefaults.standard.dictionary(forKey: Keys.usedSuggestions) as? [String: [String]] ?? [:]
        usedDiscouragement = UserDefaults.standard.stringArray(forKey: Keys.usedDiscouragement) ?? []
        usedMotivation = UserDefaults.standard.stringArray(forKey: Keys.usedMotivation) ?? []
    }

    private func persistRotation() {
        UserDefaults.standard.set(usedSuggestions, forKey: Keys.usedSuggestions)
        UserDefaults.standard.set(usedDiscouragement, forKey: Keys.usedDiscouragement)
        UserDefaults.standard.set(usedMotivation, forKey: Keys.usedMotivation)
    }
}

struct ContentEntry: Identifiable {
    let id: String
    let text: String
}
