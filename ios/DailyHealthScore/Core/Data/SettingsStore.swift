import Combine
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

    func nextSuggestion(for focus: PrimaryFocus, phase: DayPhase) -> String {
        let focusKey = focus == .maintain ? "maintain" : focus.rawValue
        let category = "\(focusKey)-\(phase.rawValue)"
        let pool = SuggestionLibrary.pool(for: focus, phase: phase)
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
        // `as? [String: [String]]` is a shallow bridge from NSDictionary in Swift: it can
        // appear to succeed while inner values are still bridged Foundation objects (e.g.
        // NSNumber if any stale plist value sneaks in). On first mutation Swift then crashes
        // with "-[__NSCFNumber count]: unrecognized selector". Validate each entry eagerly
        // and discard anything that doesn't match `[String: [String]]`.
        let raw = UserDefaults.standard.dictionary(forKey: Keys.usedSuggestions) ?? [:]
        var validated: [String: [String]] = [:]
        for (key, value) in raw {
            if let array = value as? [String] {
                validated[key] = array
            }
        }
        usedSuggestions = validated
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
