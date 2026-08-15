import Foundation

/// Last snapshot on *this* device. On the Watch this is what the complication
/// reads; on the iPhone it is only a cache of what was last sent.
enum WatchSnapshotStore {
    static func load(defaults: UserDefaults? = WatchSnapshotStore.groupedDefaults) -> WatchSnapshot? {
        guard let json = defaults?.string(forKey: WatchBridge.snapshotDefaultsKey) else { return nil }
        return WatchBridge.decode(WatchSnapshot.self, from: json)
    }

    @discardableResult
    static func save(_ snapshot: WatchSnapshot, defaults: UserDefaults? = WatchSnapshotStore.groupedDefaults) -> Bool {
        guard let json = WatchBridge.encode(snapshot) else { return false }
        defaults?.set(json, forKey: WatchBridge.snapshotDefaultsKey)
        return true
    }

    static func clear(defaults: UserDefaults? = WatchSnapshotStore.groupedDefaults) {
        defaults?.removeObject(forKey: WatchBridge.snapshotDefaultsKey)
    }

    static var groupedDefaults: UserDefaults? {
        UserDefaults(suiteName: WatchBridge.appGroupIdentifier)
    }
}
