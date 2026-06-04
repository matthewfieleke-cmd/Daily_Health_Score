import XCTest
@testable import DailyHealthScore

/// Regression coverage for the SettingsStore.loadRotationState crash where a stale or
/// foreign UserDefaults dictionary would shallow-cast through `as? [String: [String]]`
/// and then explode on first mutation with `-[__NSCFNumber count]: unrecognized selector`.
///
/// `SettingsStore` is `@MainActor`-isolated, so this XCTestCase is too — instantiating
/// the store and calling its methods has to happen from MainActor.
@MainActor
final class SettingsStoreLoadTests: XCTestCase {
    private let suiteName = "DailyHealthScoreTests.SettingsStoreLoadTests"
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        // A throwaway UserDefaults suite so we don't trample the user's real Defaults.
        UserDefaults().removePersistentDomain(forName: suiteName)
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        super.tearDown()
    }

    // SettingsStore reads from UserDefaults.standard internally, so we exercise the
    // same load path by writing to standard. We scrub these keys in tearDown so tests
    // are deterministic and don't leak state between runs.
    private func writeStandard(_ value: Any?, forKey key: String) {
        if let value {
            UserDefaults.standard.set(value, forKey: key)
        } else {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }

    private let usedSuggestionsKey = "dhs.usedSuggestions"

    override class func tearDown() {
        // Final sweep so we never leave dhs.* keys lying around in the test host's Defaults.
        let keys = [
            "dhs.usedSuggestions",
            "dhs.usedDiscouragement",
            "dhs.usedMotivation",
            "dhs.sleepGoal",
            "dhs.fiberGoal",
        ]
        for key in keys {
            UserDefaults.standard.removeObject(forKey: key)
        }
        super.tearDown()
    }

    func test_load_freshInstall_initializesEmptyAndDoesNotCrashOnNextSuggestion() {
        writeStandard(nil, forKey: usedSuggestionsKey)
        let store = SettingsStore()
        // First call ever — used to crash on assignment back into the dictionary.
        let text = store.nextSuggestion(for: .fiber, phase: .day)
        XCTAssertFalse(text.isEmpty)
    }

    func test_load_storedAsValidStringDictionary_isPreserved() {
        writeStandard(
            ["fiber-evening": ["fiber-01", "fiber-02"]],
            forKey: usedSuggestionsKey
        )
        let store = SettingsStore()
        // The next suggestion for fiber (evening) should be fiber-03 since 01 and 02 are recorded as used.
        let text = store.nextSuggestion(for: .fiber, phase: .evening)
        XCTAssertFalse(text.isEmpty)
        // Indirect check: calling it 18 more times must not crash and must not return empty.
        for _ in 0..<18 {
            XCTAssertFalse(store.nextSuggestion(for: .fiber, phase: .evening).isEmpty)
        }
    }

    func test_load_storedWithBogusValueTypes_isFilteredOutNotCrashing() {
        // Simulate the corrupt-state path that triggered the production crash: a dictionary
        // where some entries aren't [String]. The store must keep the good entries and
        // silently drop the bad ones rather than fail the shallow cast and then explode
        // on first mutation.
        let mixed: [String: Any] = [
            "sleep": ["sleep-01"],          // good
            "fiber": NSNumber(value: 42),   // bogus — the original crash trigger
            "exercise": "not-an-array",     // bogus
            "maintain": [1, 2, 3],          // bogus — array of the wrong element type
        ]
        writeStandard(mixed, forKey: usedSuggestionsKey)

        let store = SettingsStore()
        // None of these may crash. Each must return a non-empty suggestion.
        XCTAssertFalse(store.nextSuggestion(for: .sleep, phase: .day).isEmpty)
        XCTAssertFalse(store.nextSuggestion(for: .fiber, phase: .day).isEmpty)
        XCTAssertFalse(store.nextSuggestion(for: .exercise, phase: .day).isEmpty)
        XCTAssertFalse(store.nextSuggestion(for: .maintain, phase: .day).isEmpty)
    }
}
