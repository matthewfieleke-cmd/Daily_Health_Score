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

    /// Where a snapshot was built. A Watch Health reading is only a stand-in
    /// until the iPhone sends today's record. It must not paint over that record.
    enum Source: String {
        case phone
        case health
    }

    @discardableResult
    static func save(
        _ snapshot: WatchSnapshot,
        source: Source = .phone,
        defaults: UserDefaults? = WatchSnapshotStore.groupedDefaults,
        containerURL: URL? = WatchSnapshotStore.groupContainer
    ) -> Bool {
        if let existing = load(defaults: defaults, containerURL: containerURL) {
            var stored = existing
            if storedSource(defaults: defaults, containerURL: containerURL) == .health {
                stored.origin = WatchSnapshotOrigin.health
            }
            var incoming = snapshot
            if source == .health {
                incoming.origin = WatchSnapshotOrigin.health
            }
            if !WatchSnapshot.replaces(stored, with: incoming) {
                return true
            }
        }
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
        WatchNutritionModeStore.save(from: snapshot, defaults: defaults, containerURL: containerURL)
        remember(source, defaults: defaults, containerURL: containerURL)
        return wrote
    }

    static func storedSource(
        defaults: UserDefaults? = WatchSnapshotStore.groupedDefaults,
        containerURL: URL? = WatchSnapshotStore.groupContainer
    ) -> Source {
        if let file = sourceURL(containerURL: containerURL),
           let text = try? String(contentsOf: file, encoding: .utf8) {
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            if let source = Source(rawValue: trimmed) { return source }
        }
        if let raw = defaults?.string(forKey: WatchBridge.snapshotSourceDefaultsKey),
           let source = Source(rawValue: raw) {
            return source
        }
        return .phone
    }

    private static func remember(
        _ source: Source,
        defaults: UserDefaults?,
        containerURL: URL?
    ) {
        if containerURL != nil {
            defaults?.set(source.rawValue, forKey: WatchBridge.snapshotSourceDefaultsKey)
        }
        guard let file = sourceURL(containerURL: containerURL),
              let data = source.rawValue.data(using: .utf8) else { return }
        try? FileManager.default.createDirectory(
            at: file.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try? data.write(to: file, options: [.atomic, .noFileProtection])
        try? protect(file)
    }

    private static func sourceURL(containerURL: URL?) -> URL? {
        containerURL?.appendingPathComponent(WatchBridge.snapshotSourceFileName)
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
        defaults?.removeObject(forKey: WatchBridge.nutritionModeDefaultsKey)
        for file in snapshotWriteURLs(containerURL: containerURL) {
            try? FileManager.default.removeItem(at: file)
        }
        if let compact = compactFaceURL(containerURL: containerURL) {
            try? FileManager.default.removeItem(at: compact)
        }
        if let mode = nutritionModeURL(containerURL: containerURL) {
            try? FileManager.default.removeItem(at: mode)
        }
        if let source = sourceURL(containerURL: containerURL) {
            try? FileManager.default.removeItem(at: source)
        }
        defaults?.removeObject(forKey: WatchBridge.snapshotSourceDefaultsKey)
    }

    static func nutritionModeURL(containerURL: URL? = WatchSnapshotStore.groupContainer) -> URL? {
        containerURL?.appendingPathComponent(WatchBridge.nutritionModeFileName)
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

/// Last nutrition mode that arrived with a snapshot. A missing snapshot must
/// not invent a food-group score from Apple Health fiber.
enum WatchNutritionModeStore {
    static func rawMode(for snapshot: WatchSnapshot) -> String {
        snapshot.fiber.unit == "pts" ? "foodGroups" : "fiber"
    }

    static func save(
        from snapshot: WatchSnapshot,
        defaults: UserDefaults?,
        containerURL: URL?
    ) {
        let raw = rawMode(for: snapshot)
        if containerURL != nil {
            defaults?.set(raw, forKey: WatchBridge.nutritionModeDefaultsKey)
        }
        guard let file = WatchSnapshotStore.nutritionModeURL(containerURL: containerURL),
              let data = raw.data(using: .utf8) else { return }
        let folder = file.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try? data.write(to: file, options: [.atomic, .noFileProtection])
        try? WatchSnapshotStore.protect(file)
    }

    static func current(
        defaults: UserDefaults? = WatchSnapshotStore.groupedDefaults,
        containerURL: URL? = WatchSnapshotStore.groupContainer
    ) -> String {
        if let file = WatchSnapshotStore.nutritionModeURL(containerURL: containerURL),
           let text = try? String(contentsOf: file, encoding: .utf8) {
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty { return trimmed }
        }
        return defaults?.string(forKey: WatchBridge.nutritionModeDefaultsKey) ?? "fiber"
    }

    /// Health fiber can paint a face only while nutrition is still the gram goal.
    static func allowsHealthFiberFallback(
        defaults: UserDefaults? = WatchSnapshotStore.groupedDefaults,
        containerURL: URL? = WatchSnapshotStore.groupContainer
    ) -> Bool {
        current(defaults: defaults, containerURL: containerURL) != "foodGroups"
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
