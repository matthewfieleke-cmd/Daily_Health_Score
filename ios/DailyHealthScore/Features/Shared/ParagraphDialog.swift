import SwiftUI

/// A lightweight centered dialog used for the "Feeling discouraged?" and
/// "Need motivation?" paragraphs. Replaces the previous `.sheet(...)` that
/// covered most of the screen even with very short content.
///
/// Behavior:
/// - Dim backdrop fades in/out behind the card.
/// - Card scales + fades in (spring) and out (ease).
/// - Tapping the backdrop or the Done button dismisses.
/// - Respects safe area and Dynamic Type.
/// - Long paragraphs are scrollable inside the card so the dialog itself
///   never grows past ~70% of the screen height.
struct ParagraphDialog: View {
    let title: String
    let text: String
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            backdrop
            card
        }
        .transition(.opacity)
    }

    // MARK: - Backdrop

    private var backdrop: some View {
        Color.black
            .opacity(0.35)
            .ignoresSafeArea()
            .contentShape(Rectangle())
            .onTapGesture(perform: onDismiss)
            .accessibilityHidden(true)
    }

    // MARK: - Card

    private var card: some View {
        GeometryReader { proxy in
            let maxHeight = proxy.size.height * 0.70
            VStack(spacing: 0) {
                header
                Divider()
                    .background(.quaternary)
                ScrollView {
                    Text(text)
                        .font(.body)
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(20)
                }
                .scrollIndicators(.hidden)
                footer
            }
            .frame(maxWidth: 360)
            .frame(maxHeight: maxHeight)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.Layout.heroCornerRadius, style: .continuous)
                    .fill(AppTheme.cardSurface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.Layout.heroCornerRadius, style: .continuous)
                    .stroke(.white.opacity(0.06), lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.30), radius: 30, x: 0, y: 10)
            .padding(.horizontal, 24)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
        .transition(
            .scale(scale: 0.92, anchor: .center)
                .combined(with: .opacity)
        )
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.primary)
                Text("Take a breath.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(8)
                    .background(Circle().fill(Color(.tertiarySystemFill)))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Dismiss")
        }
        .padding(.horizontal, 20)
        .padding(.top, 18)
        .padding(.bottom, 14)
    }

    private var footer: some View {
        Button(action: onDismiss) {
            Text("Thanks")
                .font(.body.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(AppTheme.primary.opacity(0.12))
                .foregroundStyle(AppTheme.primary)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .padding(20)
    }
}

// MARK: - Presenter modifier

extension View {
    /// Present a `ParagraphDialog` when `isPresented` becomes true. The
    /// transition (backdrop dim, card scale/fade) is animated automatically
    /// by toggling the binding inside a `withAnimation` block.
    func paragraphDialog(
        isPresented: Binding<Bool>,
        title: String,
        text: String
    ) -> some View {
        ZStack {
            self
            if isPresented.wrappedValue {
                ParagraphDialog(title: title, text: text) {
                    withAnimation(.easeOut(duration: 0.18)) {
                        isPresented.wrappedValue = false
                    }
                }
                .zIndex(1)
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: isPresented.wrappedValue)
    }
}
