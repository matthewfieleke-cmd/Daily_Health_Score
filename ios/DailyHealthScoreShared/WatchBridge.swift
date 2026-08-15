import Foundation

/// Identifiers shared by the iPhone app, the Watch app, and the Watch complication.
///
/// An App Group is a container on *one* device. The iPhone app and the Watch app
/// each have their own copy. The same identifier string is declared in every
/// entitlement so Xcode signs them together; bytes move between devices only
/// through Watch Connectivity.
enum WatchBridge {
    static let appGroupIdentifier = "group.com.dailyhealthscore.app"
    static let snapshotDefaultsKey = "dhs.watch.snapshotJSON"
    static let applicationContextSnapshotKey = "snapshotJSON"
    static let userInfoCheckInKey = "checkInJSON"

    static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    static var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    static func encode<T: Encodable>(_ value: T) -> String? {
        guard let data = try? encoder.encode(value) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func decode<T: Decodable>(_ type: T.Type, from json: String) -> T? {
        guard let data = json.data(using: .utf8) else { return nil }
        return try? decoder.decode(type, from: data)
    }
}
