import Foundation

/// JPEG files for photos the person attached to a Coach message. The chat
/// stores the file name; the model receives the file when that turn is sent
/// or when a new session is seeded from the saved thread.
enum CoachPhotoStore {
    static let maxPerMessage = 4

    static func saveJPEG(_ data: Data, directory: URL? = nil) throws -> String {
        let folder = directory ?? storageDirectory
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let name = UUID().uuidString + ".jpg"
        guard let url = fileURL(named: name, directory: folder) else {
            throw CocoaError(.fileWriteInvalidFileName)
        }
        try data.write(to: url, options: .atomic)
        return name
    }

    static func fileURL(named name: String, directory: URL? = nil) -> URL? {
        guard name.range(of: #"^[0-9A-Fa-f-]{36}\.jpg$"#, options: .regularExpression) != nil else { return nil }
        return (directory ?? storageDirectory).appendingPathComponent(name)
    }

    static func delete(fileNames: [String], directory: URL? = nil) {
        let folder = directory ?? storageDirectory
        for name in fileNames {
            guard let url = fileURL(named: name, directory: folder) else { continue }
            try? FileManager.default.removeItem(at: url)
        }
    }

    private static var storageDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base.appendingPathComponent("CoachPhotos", isDirectory: true)
    }
}
