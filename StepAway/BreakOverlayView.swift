import SwiftUI

struct BreakOverlayView: View {
    let kind: BreakKind
    let manager: BreakManager
    let settings: AppSettings

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false
    @State private var breathing = false
    @State private var interactive = false

    private var ringSize: CGFloat { kind == .long ? 300 : 268 }
    private var ghostWord: String { kind == .short ? "LOOK AWAY" : "STAND UP" }

    var body: some View {
        ZStack {
            backdrop
            panel
            if settings.allowSkip { skipControl }
            credit
        }
        .ignoresSafeArea()
        .onAppear(perform: enter)
    }

    // MARK: - Backdrop

    private var backdrop: some View {
        ZStack {
            DesktopBlur(material: .hudWindow)

            AmberBloom(animated: !reduceMotion)

            GeometryReader { geo in
                OutlineWord(
                    word: ghostWord,
                    size: min(geo.size.height * 0.30, geo.size.width * 0.155),
                    lineWidth: 1.4,
                    tint: Theme.Palette.ink.opacity(0.075)
                )
                .frame(width: geo.size.width * 1.1, height: geo.size.height * 0.40)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                .offset(x: -geo.size.width * 0.17)
            }

            RadialGradient(
                colors: [Color.black.opacity(0.30), .clear],
                center: .center, startRadius: 0, endRadius: 660
            )

            FilmGrain(intensity: 0.13)

            RadialGradient(
                colors: [Theme.Palette.ink.opacity(0.06), .clear],
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
        VStack(spacing: 30) {
            dial
                .opacity(appeared ? 1 : 0)
                .scaleEffect(appeared ? 1 : 0.92)
                .animation(Theme.Motion.bloom, value: appeared)

            Text(manager.timeRemaining.clockText)
                .font(Theme.counter(78))
                .tracking(-3)
                .foregroundStyle(Theme.Palette.ink)
                .contentTransition(.numericText(countsDown: true))
                .animation(Theme.Motion.quick, value: manager.timeRemaining)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 10)
                .animation(Theme.Motion.bloom.delay(0.12), value: appeared)

            VStack(spacing: 14) {
                Text(kind.title)
                    .font(Theme.display(46, .black))
                    .tracking(-0.8)
                    .textCase(.uppercase)
                    .lineSpacing(-6)
                    .foregroundStyle(Theme.Palette.ink)

                Text(kind.guidance)
                    .font(Theme.voice(19))
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
                .stroke(Theme.Palette.ink.opacity(0.09), lineWidth: 6)

            Circle()
                .trim(from: 0, to: appeared ? manager.progress : 0)
                .stroke(
                    Theme.Palette.ink.opacity(0.50),
                    style: StrokeStyle(lineWidth: 9, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .blur(radius: 12)
                .opacity(breathing ? 0.9 : 0.45)
                .animation(.linear(duration: 1), value: manager.progress)

            Circle()
                .trim(from: 0, to: appeared ? manager.progress : 0)
                .stroke(
                    Theme.Palette.ink.opacity(0.88),
                    style: StrokeStyle(lineWidth: 6, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .shadow(color: Theme.Palette.ink.opacity(0.22), radius: 10)
                .animation(.linear(duration: 1), value: manager.progress)

            if kind == .short {
                EyeGlyph(animated: !reduceMotion)
                    .frame(width: ringSize * 0.70, height: ringSize * 0.32)
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
                    .microLabel(10, tracking: 0.18)
                    .foregroundStyle(Theme.Palette.inkMuted)
                    .padding(.horizontal, 26)
                    .padding(.vertical, 12)
                    .glassPill()
            }
            .buttonStyle(.plain)
            .padding(.bottom, 56)
            .opacity(appeared ? 1 : 0)
            .disabled(!interactive)
            .allowsHitTesting(interactive)
        }
    }

    private var credit: some View {
        VStack {
            Spacer()
            HStack {
                Brandmark()
                    .opacity(appeared ? 0.75 : 0)
                    .animation(Theme.Motion.bloom.delay(0.5), value: appeared)
                Spacer()
            }
        }
        .padding(28)
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
