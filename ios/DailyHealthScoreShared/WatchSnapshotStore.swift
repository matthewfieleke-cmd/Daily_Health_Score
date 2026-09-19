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
        for file in snapshotReadURLs(containerURL: containerURL) {
            let data = (try? Data(contentsOf: file, options: [.uncached]))
                ?? (try? Data(contentsOf: file))
            if let data,
               let decoded = try? WatchBridge.decoder.decode(WatchSnapshot.self, from: data) {
                return decoded
            }
        }
        if let line = compactFaceLine(containerURL: containerURL),
           let decoded = WatchSnapshot.fromCompactFaceRecord(line) {
            return decoded
        }
        if let line = defaults?.string(forKey: WatchBridge.compactFaceFileName),
           let decoded = WatchSnapshot.fromCompactFaceRecord(line) {
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
        // `UserDefaults(suiteName:)` still returns an object when the App Group
        // entitlement is missing. Those writes stay in-process and the widget
        // never sees them. Only count a suite write when the group container
        // actually exists.
        if containerURL != nil, let defaults, let json = String(data: data, encoding: .utf8) {
            defaults.set(json, forKey: WatchBridge.snapshotDefaultsKey)
            defaults.set(snapshot.compactFaceRecord, forKey: WatchBridge.compactFaceFileName)
            defaults.synchronize()
            wrote = true
        }
        for file in snapshotWriteURLs(containerURL: containerURL) {
            do {
                let folder = file.deletingLastPathComponent()
                try FileManager.default.createDirectory(
                    at: folder,
                    withIntermediateDirectories: true
                )
                try? Self.protect(folder)
                try data.write(to: file, options: [.atomic, .noFileProtection])
                try? Self.protect(file)
                if FileManager.default.fileExists(atPath: file.path) {
                    wrote = true
                }
            } catch {
                continue
            }
        }
        if let compact = compactFaceURL(containerURL: containerURL),
           let face = snapshot.compactFaceRecord.data(using: .utf8) {
            do {
                try FileManager.default.createDirectory(
                    at: compact.deletingLastPathComponent(),
                    withIntermediateDirectories: true
                )
                try face.write(to: compact, options: [.atomic, .noFileProtection])
                try? Self.protect(compact)
                if FileManager.default.fileExists(atPath: compact.path) {
                    wrote = true
                }
            } catch {
                // Compact face is a fallback, not a success on its own if the write failed.
            }
        }
        return wrote
    }

    /// False when this process is not actually in `group.com.dailyhealthscore.app.mf`.
    static var canShareGroup: Bool { groupContainer != nil }

    /// WidgetKit reads this file on a locked wrist. Complete protection makes
    /// `getTimeline` return nil and the face stays "-- / Open iPhone".
    static func protect(_ url: URL) throws {
        try FileManager.default.setAttributes(
            [.protectionKey: FileProtectionType.none],
            ofItemAtPath: url.path
        )
    }

    static func clear(
        defaults: UserDefaults? = WatchSnapshotStore.groupedDefaults,
        containerURL: URL? = WatchSnapshotStore.groupContainer
    ) {
        defaults?.removeObject(forKey: WatchBridge.snapshotDefaultsKey)
        defaults?.removeObject(forKey: WatchBridge.compactFaceFileName)
        for file in snapshotWriteURLs(containerURL: containerURL) {
            try? FileManager.default.removeItem(at: file)
        }
        if let compact = compactFaceURL(containerURL: containerURL) {
            try? FileManager.default.removeItem(at: compact)
        }
    }

    static func snapshotFileURL(containerURL: URL? = WatchSnapshotStore.groupContainer) -> URL? {
        containerURL?.appendingPathComponent(WatchBridge.snapshotFileName)
    }

    static func compactFaceURL(containerURL: URL? = WatchSnapshotStore.groupContainer) -> URL? {
        containerURL?.appendingPathComponent(WatchBridge.compactFaceFileName)
    }

    static func snapshotWriteURLs(containerURL: URL? = WatchSnapshotStore.groupContainer) -> [URL] {
        guard let containerURL else { return [] }
        return [
            containerURL.appendingPathComponent(WatchBridge.snapshotFileName),
            containerURL.appendingPathComponent(WatchBridge.snapshotSupportFileName)
        ]
    }

    static func snapshotReadURLs(containerURL: URL? = WatchSnapshotStore.groupContainer) -> [URL] {
        snapshotWriteURLs(containerURL: containerURL)
    }

    static func compactFaceLine(containerURL: URL? = WatchSnapshotStore.groupContainer) -> String? {
        guard let file = compactFaceURL(containerURL: containerURL) else { return nil }
        let data = (try? Data(contentsOf: file, options: [.uncached]))
            ?? (try? Data(contentsOf: file))
        guard let data, let line = String(data: data, encoding: .utf8) else { return nil }
        return line.trimmingCharacters(in: .whitespacesAndNewlines)
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
