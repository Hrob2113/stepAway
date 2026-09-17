import SwiftUI

struct BreakOverlayView: View {
    let kind: BreakKind
    let manager: BreakManager
    let settings: AppSettings

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false
    @State private var breathing = false
    @State private var interactive = false

    private var ringSize: CGFloat { kind == .long ? 320 : 286 }

    var body: some View {
        ZStack {
            backdrop
            panel
            if settings.allowSkip { skipControl }
        }
        .ignoresSafeArea()
        .onAppear(perform: enter)
    }

    // MARK: - Backdrop

    private var backdrop: some View {
        ZStack {
            BackdropBlur(material: .fullScreenUI)

            if !reduceMotion { DriftingOrbs() }

            RadialGradient(
                colors: [Color.white.opacity(0.07), .clear],
                center: .center, startRadius: 0, endRadius: 520
            )
            .scaleEffect(breathing ? 1.08 : 0.94)
            .opacity(breathing ? 0.9 : 0.55)
        }
        .opacity(appeared ? 1 : 0)
        .animation(Theme.Motion.bloom, value: appeared)
    }

    // MARK: - Panel

    private var panel: some View {
        VStack(spacing: 34) {
            dial
                .opacity(appeared ? 1 : 0)
                .scaleEffect(appeared ? 1 : 0.92)
                .animation(Theme.Motion.bloom, value: appeared)

            Text(manager.timeRemaining.clockText)
                .font(Theme.counter(62))
                .foregroundStyle(Theme.Palette.ink)
                .contentTransition(.numericText(countsDown: true))
                .animation(Theme.Motion.quick, value: manager.timeRemaining)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 10)
                .animation(Theme.Motion.bloom.delay(0.12), value: appeared)

            VStack(spacing: 9) {
                Text(kind.title)
                    .font(Theme.rounded(26, .medium))
                    .foregroundStyle(Theme.Palette.ink)
                Text(kind.guidance)
                    .font(Theme.rounded(16))
                    .foregroundStyle(Theme.Palette.inkMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .multilineTextAlignment(.center)
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 14)
            .animation(Theme.Motion.bloom.delay(0.22), value: appeared)
        }
    }

    private var dial: some View {
        ZStack {
            Circle()
                .stroke(Theme.Palette.ink.opacity(0.10), lineWidth: 7)

            Circle()
                .trim(from: 0, to: appeared ? manager.progress : 0)
                .stroke(
                    Theme.Palette.chalk.opacity(0.55),
                    style: StrokeStyle(lineWidth: 9, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .blur(radius: 12)
                .opacity(breathing ? 0.9 : 0.45)
                .animation(.linear(duration: 1), value: manager.progress)

            Circle()
                .trim(from: 0, to: appeared ? manager.progress : 0)
                .stroke(
                    AngularGradient(
                        colors: [
                            Theme.Palette.chalk,
                            Theme.Palette.ink,
                            Theme.Palette.chalk
                        ],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 7, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .shadow(color: Theme.Palette.chalk.opacity(0.25), radius: 10)
                .animation(.linear(duration: 1), value: manager.progress)

            if kind == .short {
                EyesGlyph(animated: !reduceMotion)
                    .frame(width: ringSize * 0.54, height: ringSize * 0.32)
            } else {
                StretchGlyph(animated: !reduceMotion)
                    .frame(width: ringSize * 0.44, height: ringSize * 0.54)
            }
        }
        .frame(width: ringSize, height: ringSize)
    }

    private var skipControl: some View {
        VStack {
            Spacer()
            Button(action: manager.skipBreak) {
                Text("Skip this break")
                    .font(Theme.rounded(13))
                    .foregroundStyle(Theme.Palette.inkMuted)
                    .padding(.horizontal, 22)
                    .padding(.vertical, 10)
                    .glassCapsule(tint: Theme.Palette.glass, intensity: 0.35)
            }
            .buttonStyle(.plain)
            .padding(.bottom, 54)
            .opacity(appeared ? 1 : 0)
            .disabled(!interactive)
            .allowsHitTesting(interactive)
        }
    }

    // MARK: - Entrance

    private func enter() {
        armSkip()
        guard !reduceMotion else {
            appeared = true
            return
        }
        appeared = true
        withAnimation(Theme.Motion.breathe.delay(0.9)) { breathing = true }
    }

    private func armSkip() {
        Task {
            try? await Task.sleep(for: .milliseconds(1200))
            interactive = true
        }
    }
}
