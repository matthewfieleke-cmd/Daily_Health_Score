import SwiftUI

/// Centralized brand colors, spacing, and shape tokens for the app.
///
/// Colors are pulled from the DHS app-icon palette (deep navy/teal background,
/// vibrant teal-blue ring, fresh green leaf, soft cream highlight). Each token
/// adapts between light and dark mode so the app feels native in both.
///
/// Use these tokens instead of hard-coded `Color(red: ..., green: ..., blue: ...)`
/// calls so the entire UI moves together when the brand evolves.
enum AppTheme {
    // MARK: - Brand palette

    /// Primary brand tint — the teal-blue ring around the icon. Used for the
    /// tab bar tint, navigation accents, and progress fills on light tinted
    /// surfaces.
    static let primary = Color(
        light: Color(red: 0.25, green: 0.55, blue: 0.72),  // #4090B8
        dark:  Color(red: 0.39, green: 0.71, blue: 0.84)   // #65B5D7
    )

    /// Deep background color from the icon — used as a "hero" surface behind
    /// the score on the Today screen and behind the brand mark.
    static let backgroundDeep = Color(
        light: Color(red: 0.06, green: 0.15, blue: 0.23),  // #0F263A
        dark:  Color(red: 0.04, green: 0.10, blue: 0.16)   // #0A1929
    )

    /// Mid-tone surface color used in gradients with `backgroundDeep`.
    static let backgroundMid = Color(
        light: Color(red: 0.18, green: 0.37, blue: 0.52),  // #2D5F85
        dark:  Color(red: 0.10, green: 0.21, blue: 0.30)   // #1A364D
    )

    /// Fresh leaf-green from the icon — represents positive momentum.
    /// Used for "goal met" indicators and the maintenance focus.
    static let leaf = Color(
        light: Color(red: 0.31, green: 0.74, blue: 0.42),  // #4FBC6B
        dark:  Color(red: 0.49, green: 0.86, blue: 0.55)   // #7DDB8C
    )

    /// Soft cream highlight from the icon's "10/10" text.
    static let highlight = Color(
        light: Color(red: 0.95, green: 0.92, blue: 0.78),  // #F3EBC8
        dark:  Color(red: 0.95, green: 0.92, blue: 0.78)
    )

    // MARK: - Surface tokens

    /// The card / grouped-content surface. Adapts to the system grouped style.
    static let cardSurface = Color(.secondarySystemGroupedBackground)

    /// The screen background behind cards.
    static let screenBackground = Color(.systemGroupedBackground)

    // MARK: - Per-metric tints

    static func tint(for focus: PrimaryFocus) -> Color {
        switch focus {
        case .sleep:    return primary
        case .fiber:    return leaf
        case .exercise: return Color(red: 0.94, green: 0.55, blue: 0.32) // warm orange — energy
        case .maintain: return highlight
        }
    }

    static func symbol(for focus: PrimaryFocus) -> String {
        switch focus {
        case .sleep:    return "moon.stars.fill"
        case .fiber:    return "leaf.fill"
        case .exercise: return "figure.run"
        case .maintain: return "checkmark.seal.fill"
        }
    }

    static func tint(for theme: SMARTRelevantTheme) -> Color {
        switch theme {
        case .marriage: return Color(red: 0.85, green: 0.45, blue: 0.55)
        case .parenting: return Color(red: 0.94, green: 0.55, blue: 0.32)
        case .health: return primary
        case .relationships: return Color(red: 0.62, green: 0.47, blue: 0.86)
        case .finances: return Color(red: 0.20, green: 0.63, blue: 0.42)
        case .career: return Color(red: 0.30, green: 0.45, blue: 0.78)
        case .choresMisc: return Color(red: 0.49, green: 0.53, blue: 0.61)
        }
    }

    // MARK: - Layout tokens

    enum Layout {
        static let cardCornerRadius: CGFloat = 16
        static let cardPadding: CGFloat = 16
        static let sectionSpacing: CGFloat = 20
        static let stackSpacing: CGFloat = 12
        static let heroCornerRadius: CGFloat = 24
        /// Taller than the system default so sync status pills can sit centered in the nav row.
        static let navigationBarRowHeight: CGFloat = 60
    }

    enum Shadow {
        static let card = ShadowStyle(
            color: Color.black.opacity(0.06),
            radius: 8,
            x: 0,
            y: 2
        )
    }

    struct ShadowStyle {
        let color: Color
        let radius: CGFloat
        let x: CGFloat
        let y: CGFloat
    }

    // MARK: - Gradients

    /// Hero gradient that mirrors the icon background (deep at the bottom,
    /// brighter teal at the top).
    static var heroGradient: LinearGradient {
        LinearGradient(
            colors: [backgroundMid, backgroundDeep],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

// MARK: - Color helpers

extension Color {
    /// Build a Color that resolves to one shade in light mode and another in dark.
    init(light: Color, dark: Color) {
        self = Color(UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor(dark)
                : UIColor(light)
        })
    }
}

extension View {
    /// Apply the standard card shadow defined in `AppTheme.Shadow.card`.
    func cardShadow() -> some View {
        let s = AppTheme.Shadow.card
        return shadow(color: s.color, radius: s.radius, x: s.x, y: s.y)
    }

    /// Wrap any content in the canonical card chrome — rounded corners,
    /// surface color, padding, and the brand shadow.
    func dhsCard(padding: CGFloat = AppTheme.Layout.cardPadding) -> some View {
        self
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppTheme.cardSurface)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Layout.cardCornerRadius, style: .continuous))
            .cardShadow()
    }
}
