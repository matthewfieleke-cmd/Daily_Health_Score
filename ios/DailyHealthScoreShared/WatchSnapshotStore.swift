import Foundation

/// Last snapshot on *this* device. On the Watch this is what the complication
/// reads; on the iPhone it is only a cache of what was last sent.
///
/// Written to both the App Group file and UserDefaults. Watch widgets are a
/// separate process and often see a stale or empty UserDefaults suite; the
/// file in the group container is the source they can actually read.
enum WatchSnapshotStore {
    static func load(
        defaults: UserDefaults? = WatchSnapshotStore.groupedDefaults,
        containerURL: URL? = WatchSnapshotStore.groupContainer
    ) -> WatchSnapshot? {
        if let file = snapshotFileURL(containerURL: containerURL),
           let data = try? Data(contentsOf: file),
           let decoded = try? WatchBridge.decoder.decode(WatchSnapshot.self, from: data) {
            return decoded
        }
        guard let json = defaults?.string(forKey: WatchBridge.snapshotDefaultsKey) else { return nil }
        return WatchBridge.decode(WatchSnapshot.self, from: json)
    }

    @discardableResult
    static func save(
        _ snapshot: WatchSnapshot,
        defaults: UserDefaults? = WatchSnapshotStore.groupedDefaults,
        containerURL: URL? = WatchSnapshotStore.groupContainer
    ) -> Bool {
        guard let data = try? WatchBridge.encoder.encode(snapshot) else { return false }
        var wrote = false
        if let json = String(data: data, encoding: .utf8) {
            defaults?.set(json, forKey: WatchBridge.snapshotDefaultsKey)
            wrote = true
        }
        if let file = snapshotFileURL(containerURL: containerURL) {
            do {
                try FileManager.default.createDirectory(
                    at: file.deletingLastPathComponent(),
                    withIntermediateDirectories: true
                )
                try data.write(to: file, options: .atomic)
                wrote = true
            } catch {
                // UserDefaults copy may still be enough for the Watch app itself.
            }
        }
        return wrote
    }

    static func clear(
        defaults: UserDefaults? = WatchSnapshotStore.groupedDefaults,
        containerURL: URL? = WatchSnapshotStore.groupContainer
    ) {
        defaults?.removeObject(forKey: WatchBridge.snapshotDefaultsKey)
        if let file = snapshotFileURL(containerURL: containerURL) {
            try? FileManager.default.removeItem(at: file)
        }
    }

    static func snapshotFileURL(containerURL: URL? = WatchSnapshotStore.groupContainer) -> URL? {
        containerURL?.appendingPathComponent(WatchBridge.snapshotFileName)
    }

    static var groupContainer: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: WatchBridge.appGroupIdentifier)
    }

    static var groupedDefaults: UserDefaults? {
        UserDefaults(suiteName: WatchBridge.appGroupIdentifier)
    }
}

/// Check-ins that have not yet been handed to `WCSession.transferUserInfo`.
enum WatchPendingCheckInStore {
    static func load(defaults: UserDefaults? = WatchSnapshotStore.groupedDefaults) -> [WatchCheckInEvent] {
        guard let json = defaults?.string(forKey: WatchBridge.pendingCheckInsDefaultsKey) else { return [] }
        return WatchBridge.decode([WatchCheckInEvent].self, from: json) ?? []
    }

    static func save(_ events: [WatchCheckInEvent], defaults: UserDefaults? = WatchSnapshotStore.groupedDefaults) {
        if events.isEmpty {
            defaults?.removeObject(forKey: WatchBridge.pendingCheckInsDefaultsKey)
            return
        }
        guard let json = WatchBridge.encode(events) else { return }
        defaults?.set(json, forKey: WatchBridge.pendingCheckInsDefaultsKey)
    }
}
