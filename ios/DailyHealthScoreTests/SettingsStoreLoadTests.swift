import XCTest
@testable import DailyHealthScore

/// SettingsStore load and pace-nudge defaults. The old suggestion-pool
/// UserDefaults crash path is gone with that pipeline.
@MainActor
final class SettingsStoreLoadTests: XCTestCase {
    private let suiteName = "DailyHealthScoreTests.SettingsStoreLoadTests"
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        UserDefaults().removePersistentDomain(forName: suiteName)
        defaults = UserDefaults(suiteName: suiteName)
        writeStandard(nil, forKey: "dhs.paceNudgesEnabled")
        writeStandard(nil, forKey: "dhs.usedSuggestions")
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        super.tearDown()
    }

    private func writeStandard(_ value: Any?, forKey key: String) {
        if let value {
            UserDefaults.standard.set(value, forKey: key)
        } else {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }

    override class func tearDown() {
        let keys = [
            "dhs.usedSuggestions",
            "dhs.usedDiscouragement",
            "dhs.usedMotivation",
            "dhs.sleepGoal",
            "dhs.fiberGoal",
            "dhs.paceNudgesEnabled",
        ]
        for key in keys {
            UserDefaults.standard.removeObject(forKey: key)
        }
        super.tearDown()
    }

    func test_load_freshInstallDoesNotCrash() {
        let store = SettingsStore()
        XCTAssertEqual(store.settings.fiberGoal, .forty)
        store.clearRotationState()
        XCTAssertNil(UserDefaults.standard.object(forKey: "dhs.usedSuggestions"))
    }

    func test_paceNudgesDefaultOnWhenKeyMissing() {
        writeStandard(nil, forKey: "dhs.paceNudgesEnabled")
        let store = SettingsStore()
        XCTAssertTrue(store.paceNudgesEnabled)
    }

    func test_paceNudgesRespectsStoredFalse() {
        writeStandard(false, forKey: "dhs.paceNudgesEnabled")
        let store = SettingsStore()
        XCTAssertFalse(store.paceNudgesEnabled)
        writeStandard(nil, forKey: "dhs.paceNudgesEnabled")
    }

    func test_clearRotationStateDropsRetiredSuggestionKey() {
        writeStandard(["fiber-evening": ["fiber-01"]], forKey: "dhs.usedSuggestions")
        let store = SettingsStore()
        store.clearRotationState()
        XCTAssertNil(UserDefaults.standard.object(forKey: "dhs.usedSuggestions"))
    }
}
