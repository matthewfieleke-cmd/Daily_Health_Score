import SwiftUI

/// Drawn food-group marks in the app colors. Not photos, and not a generic leaf.
struct FoodGroupIcon: View {
    let group: FoodGroup

    var body: some View {
        ZStack {
            Circle()
                .fill(tint.opacity(0.16))
            mark
        }
        .accessibilityHidden(true)
    }

    private var tint: Color {
        group == .limited ? AppTheme.primary : AppTheme.leaf
    }

    @ViewBuilder
    private var mark: some View {
        switch group {
        case .vegetables:
            BroccoliMark()
        case .fruit:
            BerryMark()
        case .wholeGrains:
            OatMark()
        case .legumesNuts:
            BeanMark()
        case .fish:
            FilletMark()
        case .limited:
            GlassMark()
        }
    }
}

private struct BroccoliMark: View {
    var body: some View {
        ZStack {
            Capsule()
                .fill(AppTheme.leaf)
                .frame(width: 4, height: 14)
                .offset(y: 8)
            Circle().fill(AppTheme.leaf).frame(width: 12, height: 12).offset(y: -2)
            Circle().fill(AppTheme.leaf).frame(width: 9, height: 9).offset(x: -8, y: 2)
            Circle().fill(AppTheme.leaf).frame(width: 9, height: 9).offset(x: 8, y: 2)
            Circle().fill(AppTheme.primary.opacity(0.85)).frame(width: 6, height: 6).offset(x: -3, y: -7)
        }
    }
}

private struct BerryMark: View {
    var body: some View {
        ZStack {
            Circle().fill(AppTheme.primary).frame(width: 11, height: 11).offset(x: -5, y: 3)
            Circle().fill(AppTheme.leaf).frame(width: 11, height: 11).offset(x: 5, y: 3)
            Circle().fill(AppTheme.primary).frame(width: 10, height: 10).offset(y: -5)
            Capsule()
                .fill(AppTheme.leaf)
                .frame(width: 3, height: 7)
                .offset(y: -12)
        }
    }
}

private struct OatMark: View {
    var body: some View {
        ZStack {
            Capsule()
                .fill(AppTheme.primary.opacity(0.35))
                .frame(width: 22, height: 10)
                .offset(y: 6)
            Ellipse()
                .fill(AppTheme.highlight)
                .frame(width: 8, height: 5)
                .offset(x: -5, y: 1)
            Ellipse()
                .fill(AppTheme.highlight)
                .frame(width: 8, height: 5)
                .offset(x: 4, y: 2)
            Ellipse()
                .fill(AppTheme.primary)
                .frame(width: 7, height: 4)
                .offset(y: -2)
        }
    }
}

private struct BeanMark: View {
    var body: some View {
        ZStack {
            Capsule()
                .fill(AppTheme.leaf)
                .frame(width: 14, height: 8)
                .rotationEffect(.degrees(-30))
                .offset(x: -4, y: 2)
            Capsule()
                .fill(AppTheme.primary)
                .frame(width: 12, height: 7)
                .rotationEffect(.degrees(25))
                .offset(x: 5, y: -1)
            Circle()
                .fill(AppTheme.highlight)
                .frame(width: 6, height: 6)
                .offset(x: 1, y: 7)
        }
    }
}

private struct FilletMark: View {
    var body: some View {
        ZStack {
            Capsule()
                .fill(AppTheme.primary)
                .frame(width: 22, height: 10)
                .rotationEffect(.degrees(-18))
            Circle()
                .fill(AppTheme.highlight)
                .frame(width: 3, height: 3)
                .offset(x: 4, y: -2)
        }
    }
}

private struct GlassMark: View {
    var body: some View {
        ZStack {
            GlassShape()
                .stroke(AppTheme.primary, lineWidth: 1.6)
            GlassShape()
                .fill(AppTheme.primary.opacity(0.18))
            Capsule()
                .fill(AppTheme.primary.opacity(0.45))
                .frame(width: 10, height: 6)
                .offset(y: 2)
        }
    }
}

private struct GlassShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let top = rect.midY - rect.height * 0.28
        let bottom = rect.midY + rect.height * 0.32
        path.move(to: CGPoint(x: rect.midX - rect.width * 0.28, y: top))
        path.addLine(to: CGPoint(x: rect.midX + rect.width * 0.28, y: top))
        path.addLine(to: CGPoint(x: rect.midX + rect.width * 0.16, y: bottom))
        path.addLine(to: CGPoint(x: rect.midX - rect.width * 0.16, y: bottom))
        path.closeSubpath()
        return path
    }
}
