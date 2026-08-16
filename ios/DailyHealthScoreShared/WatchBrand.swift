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

/// Filling teal → leaf ring with the score in the middle. Shared by the Watch
/// app and the complication. The in-app Today page adds “of 10” underneath;
/// the complication does not.
struct WatchScoreRing: View {
    let score: Double
    var lineWidth: CGFloat? = nil
    var placeholder: Bool = false

    private var fraction: Double { max(0, min(score / 10, 1)) }
    private var label: String {
        placeholder ? "--" : String(format: "%.1f", (score * 10).rounded() / 10)
    }

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            let stroke = lineWidth ?? max(side * 0.09, 3)
            ZStack {
                Circle()
                    .stroke(WatchBrand.primary.opacity(0.22), lineWidth: stroke)
                Circle()
                    .trim(from: 0, to: placeholder ? 0 : fraction)
                    .stroke(
                        WatchBrand.ringColor(fraction: fraction),
                        style: StrokeStyle(lineWidth: stroke, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                Text(label)
                    .font(.system(size: side * 0.32, weight: .bold, design: .rounded))
                    .minimumScaleFactor(0.45)
                    .lineLimit(1)
                    .monospacedDigit()
            }
            .frame(width: side, height: side)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityLabel("Daily score")
        .accessibilityValue(placeholder ? "No score yet" : "\(label) out of ten")
    }
}
#endif
