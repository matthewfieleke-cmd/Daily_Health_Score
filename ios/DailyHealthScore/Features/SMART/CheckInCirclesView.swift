import SwiftUI

/// Empty / filled circles for SMART goal check-ins.
struct CheckInCirclesView: View {
    let targetCount: Int
    let filledMask: Int
    let tint: Color
    let enabled: Bool
    let onTap: (Int) -> Void

    var body: some View {
        HStack(spacing: 10) {
            ForEach(0 ..< targetCount, id: \.self) { index in
                Button {
                    onTap(index)
                } label: {
                    Circle()
                        .strokeBorder(tint, lineWidth: 2)
                        .background(
                            Circle()
                                .fill(isFilled(index) ? tint : Color.clear)
                        )
                        .frame(width: 32, height: 32)
                        .overlay {
                            if isFilled(index) {
                                Image(systemName: "checkmark")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(.white)
                            }
                        }
                }
                .buttonStyle(.plain)
                .disabled(!enabled)
                .accessibilityLabel(isFilled(index) ? "Check-in \(index + 1) completed" : "Check-in \(index + 1)")
            }
        }
    }

    private func isFilled(_ index: Int) -> Bool {
        (filledMask & (1 << index)) != 0
    }
}
