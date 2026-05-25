import SwiftUI

/// Coordinated ease-in-out dial-up for Today metrics (1.5s).
enum DialUpAnimation {
    static let duration: TimeInterval = 1.5
    static var timing: Animation { .easeInOut(duration: duration) }

    /// Animate `progress` from 0 → 1 over `duration`.
    @MainActor
    static func run(progress: Binding<Double>) {
        progress.wrappedValue = 0
        withAnimation(timing) {
            progress.wrappedValue = 1
        }
    }
}
