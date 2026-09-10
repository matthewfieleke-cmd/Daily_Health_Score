import SwiftUI

struct AskCoachButton: View {
    var title: String = "Ask Coach about this"
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: "bubble.left.and.text.bubble.right")
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.bordered)
        .accessibilityHint("Opens Lifestyle Coach with this screen’s current numbers.")
    }
}

struct CoachLocalFeedbackBar: View {
    var target: String
    var goalId: UUID?
    var onChoice: (Bool) -> Void

    var body: some View {
        HStack(spacing: 12) {
            Text("Was this useful?")
                .font(.caption)
                .foregroundStyle(.secondary)
            Button("Yes") { onChoice(true) }
                .buttonStyle(.bordered)
            Button("Not really") { onChoice(false) }
                .buttonStyle(.bordered)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Was this \(target) useful?")
    }
}
