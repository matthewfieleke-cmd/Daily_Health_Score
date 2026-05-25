import SwiftUI
import UIKit

/// Coordinated ease-in-out dial-up for Today metrics (1.5s).
enum DialUpAnimation {
    static let duration: TimeInterval = 1.5
    static var timing: Animation { .easeInOut(duration: duration) }

    /// Drive `setProgress` from 0 → 1 over `duration` using ease-in-out steps.
    /// Stepped updates are more reliable than `withAnimation` on a single
    /// `@State` when many derived labels and trims must stay in sync.
    @MainActor
    static func animate(setProgress: @escaping (Double) -> Void) async {
        if UIAccessibility.isReduceMotionEnabled {
            setProgress(1)
            return
        }

        setProgress(0)
        let steps = 45
        let stepNanos = UInt64((duration / Double(steps)) * 1_000_000_000)

        for step in 1...steps {
            if Task.isCancelled { return }
            try? await Task.sleep(nanoseconds: stepNanos)
            setProgress(easeInOut(Double(step) / Double(steps)))
        }
        setProgress(1)
    }

    static func easeInOut(_ t: Double) -> Double {
        t < 0.5 ? 2 * t * t : 1 - pow(-2 * t + 2, 2) / 2
    }
}
