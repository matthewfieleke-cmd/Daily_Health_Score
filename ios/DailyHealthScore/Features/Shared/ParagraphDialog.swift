import SwiftUI

/// A lightweight centered dialog used for the "Feeling discouraged?" and
/// "Need motivation?" paragraphs. Replaces the previous `.sheet(...)` that
/// covered most of the screen even with very short content.
///
/// Behavior:
/// - Dim backdrop fades in/out behind the card.
/// - Card scales + fades in (spring) and out (ease).
/// - Tapping the backdrop or Thanks dismisses.
/// - Respects safe area and Dynamic Type.
/// - Long paragraphs fall back to a scrollable body capped at ~70% of the
///   screen height; short copy sizes the card to its content.
struct ParagraphDialog: View {
    let title: String
    let text: String
    let onDismiss: () -> Void

    private let bodyPadding: CGFloat = 20

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
            let maxCardHeight = proxy.size.height * 0.70
            VStack(spacing: 0) {
                header
                Divider()
                    .background(.quaternary)
                ViewThatFits(in: .vertical) {
                    paragraphBody
                    ScrollView {
                        paragraphBody
                    }
                    .frame(maxHeight: maxScrollBodyHeight(maxCardHeight: maxCardHeight))
                }
                footer
            }
            .frame(maxWidth: 360)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxHeight: maxCardHeight)
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

    private var paragraphBody: some View {
        Text(text)
            .font(.body)
            .foregroundStyle(.primary)
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, bodyPadding)
            .padding(.top, bodyPadding)
            .padding(.bottom, bodyPadding)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.headline.weight(.semibold))
                .foregroundStyle(.primary)
            Text("Take a breath.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, bodyPadding)
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
        .padding(.horizontal, bodyPadding)
        .padding(.bottom, bodyPadding)
    }

    /// Scroll body height when `ViewThatFits` chooses the scrollable variant.
    private func maxScrollBodyHeight(maxCardHeight: CGFloat) -> CGFloat {
        // Header ~70pt + divider + body padding + footer ~68pt (approximate).
        max(120, maxCardHeight - 150)
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
