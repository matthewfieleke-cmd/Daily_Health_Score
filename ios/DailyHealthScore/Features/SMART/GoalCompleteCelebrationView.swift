import SwiftUI

/// Celebratory overlay shown when a SMART goal's last check-in is filled.
/// Fireworks are confined to roughly the middle third of the screen.
struct GoalCompleteCelebrationView: View {
    let goalTitle: String
    let onEdit: () -> Void
    let onDone: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var iconBounceToken = 0

    var body: some View {
        GeometryReader { proxy in
            let midBand = middleBand(in: proxy.size)

            ZStack {
                Color.black
                    .opacity(0.40)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture(perform: onEdit)
                    .accessibilityHidden(true)

                fireworksLayer(in: midBand)
                    .frame(width: proxy.size.width, height: midBand.height)
                    .position(x: proxy.size.width / 2, y: midBand.midY)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)

                card
                    .frame(maxWidth: min(proxy.size.width - 48, 340))
                    .position(x: proxy.size.width / 2, y: midBand.midY)
            }
        }
        .ignoresSafeArea()
        .transition(.opacity)
        .accessibilityAddTraits(.isModal)
        .onAppear {
            guard !reduceMotion else { return }
            iconBounceToken += 1
        }
    }

    private var card: some View {
        VStack(spacing: 0) {
            VStack(spacing: 8) {
                Image(systemName: "party.popper.fill")
                    .font(.system(size: 34))
                    .foregroundStyle(AppTheme.leaf)
                    .symbolEffect(.bounce, value: iconBounceToken)
                    .accessibilityHidden(true)

                Text("Goal complete!")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)

                Text("You finished “\(goalTitle)”. Nice work.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Text("Tap Edit to change check-ins, or Done to clear this goal from your list.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.top, 2)
            }
            .padding(.horizontal, 18)
            .padding(.top, 22)
            .padding(.bottom, 16)

            HStack(spacing: 10) {
                Button(action: onEdit) {
                    Text("Edit")
                        .font(.body.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.primary.opacity(0.06))
                        .foregroundStyle(.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)

                Button(action: onDone) {
                    Text("Done")
                        .font(.body.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(AppTheme.primary)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
        .background(
            RoundedRectangle(cornerRadius: AppTheme.Layout.heroCornerRadius, style: .continuous)
                .fill(AppTheme.cardSurface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.Layout.heroCornerRadius, style: .continuous)
                .stroke(.white.opacity(0.06), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.28), radius: 28, x: 0, y: 10)
        .transition(
            .scale(scale: 0.92, anchor: .center)
                .combined(with: .opacity)
        )
    }

    @ViewBuilder
    private func fireworksLayer(in band: CGRect) -> some View {
        if reduceMotion {
            EmptyView()
        } else {
            FireworksBurstView(size: band.size)
        }
    }

    private func middleBand(in size: CGSize) -> CGRect {
        let height = size.height / 3
        let y = (size.height - height) / 2
        return CGRect(x: 0, y: y, width: size.width, height: height)
    }
}

// MARK: - Fireworks

private struct FireworkParticle: Identifiable {
    let id: Int
    let origin: CGPoint
    let angle: Double
    let speed: CGFloat
    let color: Color
    let size: CGFloat
    let delay: Double
    let lifespan: Double
}

private struct FireworksBurstView: View {
    let size: CGSize

    private let particles: [FireworkParticle]
    private let startDate = Date()

    init(size: CGSize) {
        self.size = size
        self.particles = Self.makeParticles(in: size)
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30)) { context in
            let elapsed = context.date.timeIntervalSince(startDate)
            Canvas { context, _ in
                for particle in particles {
                    let local = elapsed - particle.delay
                    guard local >= 0, local <= particle.lifespan else { continue }

                    let progress = local / particle.lifespan
                    let distance = particle.speed * CGFloat(local)
                    let gravity = CGFloat(local * local) * 90
                    let x = particle.origin.x + cos(particle.angle) * distance
                    let y = particle.origin.y + sin(particle.angle) * distance + gravity
                    let opacity = max(0, 1 - progress)
                    let radius = particle.size * (1 - CGFloat(progress) * 0.35)

                    var circle = context
                    circle.opacity = opacity
                    circle.fill(
                        Path(ellipseIn: CGRect(
                            x: x - radius / 2,
                            y: y - radius / 2,
                            width: radius,
                            height: radius
                        )),
                        with: .color(particle.color)
                    )
                }
            }
        }
        .allowsHitTesting(false)
    }

    private static func makeParticles(in size: CGSize) -> [FireworkParticle] {
        let colors: [Color] = [
            AppTheme.primary,
            AppTheme.leaf,
            Color(red: 0.94, green: 0.55, blue: 0.32),
            AppTheme.highlight,
            Color(red: 0.85, green: 0.45, blue: 0.55),
            Color(red: 0.62, green: 0.47, blue: 0.86)
        ]

        let origins = [
            CGPoint(x: size.width * 0.28, y: size.height * 0.42),
            CGPoint(x: size.width * 0.50, y: size.height * 0.28),
            CGPoint(x: size.width * 0.72, y: size.height * 0.46)
        ]

        var result: [FireworkParticle] = []
        var nextID = 0
        for (burstIndex, origin) in origins.enumerated() {
            let delay = Double(burstIndex) * 0.18
            for i in 0 ..< 18 {
                let angle = (Double(i) / 18.0) * (.pi * 2) + Double(burstIndex) * 0.2
                let speedVariety = 55 + CGFloat((i * 7 + burstIndex * 13) % 56)
                let sizeVariety = 3.5 + CGFloat((i + burstIndex) % 4) * 0.75
                result.append(
                    FireworkParticle(
                        id: nextID,
                        origin: origin,
                        angle: angle,
                        speed: speedVariety,
                        color: colors[(burstIndex + i) % colors.count],
                        size: sizeVariety,
                        delay: delay,
                        lifespan: 1.35
                    )
                )
                nextID += 1
            }
        }
        return result
    }
}

// MARK: - Presenter

extension View {
    func goalCompleteCelebration(
        isPresented: Binding<Bool>,
        goalTitle: String,
        onEdit: @escaping () -> Void,
        onDone: @escaping () -> Void
    ) -> some View {
        ZStack {
            self
            if isPresented.wrappedValue {
                GoalCompleteCelebrationView(
                    goalTitle: goalTitle,
                    onEdit: {
                        withAnimation(.easeOut(duration: 0.18)) {
                            isPresented.wrappedValue = false
                        }
                        onEdit()
                    },
                    onDone: {
                        withAnimation(.easeOut(duration: 0.18)) {
                            isPresented.wrappedValue = false
                        }
                        onDone()
                    }
                )
                .zIndex(2)
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: isPresented.wrappedValue)
    }
}
