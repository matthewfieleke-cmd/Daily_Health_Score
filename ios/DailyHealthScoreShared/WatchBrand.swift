#if canImport(SwiftUI)
import SwiftUI

/// Teal → leaf, matching the iPhone score ring. Shared so the Watch app and
/// the complication draw the same colors.
enum WatchBrand {
    static let primary = Color(red: 0.25, green: 0.55, blue: 0.72)
    static let leaf = Color(red: 0.31, green: 0.74, blue: 0.42)
    static let deep = Color(red: 0.06, green: 0.15, blue: 0.23)
    static let exercise = Color(red: 0.94, green: 0.55, blue: 0.32)

    static func ringColor(fraction: Double) -> Color {
        let t = max(0, min(fraction, 1))
        return Color(
            red: 0.25 + (0.31 - 0.25) * t,
            green: 0.55 + (0.74 - 0.55) * t,
            blue: 0.72 + (0.42 - 0.72) * t
        )
    }

    static func tint(for pillar: String) -> Color {
        switch pillar.lowercased() {
        case "sleep": return primary
        case "fiber": return leaf
        case "exercise": return exercise
        default: return primary
        }
    }
}
#endif
