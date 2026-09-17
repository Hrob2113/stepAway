import SwiftUI

struct MenuBarContentView: View {
    let manager: BreakManager
    let settings: AppSettings

    @State private var showingPauseOptions = false

    private var stateLabel: String {
        if manager.isPaused { return "Paused" }
        if manager.isResting { return "Break in progress" }
        return "Next break"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            SectionLabel("Session").padding(.top, 20).padding(.bottom, 9)
            actions

            SectionLabel("App").padding(.top, 18).padding(.bottom, 9)
            footer

            Brandmark().padding(.top, 18).padding(.leading, 10)
        }
        .padding(14)
        .frame(width: 300)
        .background {
            ZStack {
                DesktopBlur(material: .hudWindow)
                Theme.Palette.surface
                AmberBloom(intensity: 0.85)
                FilmGrain(intensity: 0.09)
            }
        }
        .overlay(alignment: .top) {
            LinearGradient(
                colors: [Color.white.opacity(0.10), .clear],
                startPoint: .top, endPoint: .bottom
            )
            .frame(height: 96)
            .allowsHitTesting(false)
        }
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color.white.opacity(0.14))
                .frame(height: 1)
                .allowsHitTesting(false)
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 13) {
                Group {
                    if manager.isPaused {
                        Image(systemName: "pause")
                            .font(.system(size: 17, weight: .light))
                            .foregroundStyle(Theme.Palette.chalk)
                    } else {
                        HourglassGlyph(progress: manager.progress)
                    }
                }
                .frame(width: 24, height: 33)

                VStack(alignment: .leading, spacing: 4) {
                    Text(stateLabel)
                        .microLabel(9, tracking: 0.26)
                        .foregroundStyle(Theme.Palette.ink.opacity(0.34))

                    if manager.isPaused, manager.timeRemaining == 0 {
                        Text("Until tomorrow")
                            .font(Theme.voice(19))
                            .foregroundStyle(Theme.Palette.ink)
                    } else {
                        Text(manager.timeRemaining.clockText)
                            .font(Theme.counter(30))
                            .tracking(-0.5)
                            .foregroundStyle(Theme.Palette.ink)
                            .contentTransition(.numericText(countsDown: true))
                            .animation(Theme.Motion.quick, value: manager.timeRemaining)
                    }
                }
                Spacer(minLength: 0)
            }

            if !manager.isPaused {
                progressBar
                if !manager.cycleProgress.isEmpty {
                    Text(manager.cycleProgress)
                        .microLabel(9, tracking: 0.08)
                        .foregroundStyle(Theme.Palette.ink.opacity(0.30))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.top, 6)
    }

    private var progressBar: some View {
        Capsule()
            .fill(Theme.Palette.ink.opacity(0.10))
            .frame(height: 3)
            .overlay(alignment: .leading) {
                GeometryReader { geo in
                    Capsule()
                        .fill(Theme.Palette.ink.opacity(0.78))
                        .frame(width: geo.size.width * manager.progress)
                        .animation(.linear(duration: 1), value: manager.progress)
                }
            }
    }

    // MARK: - Actions

    @ViewBuilder
    private var actions: some View {
        if manager.isResting {
            MenuRow("Finish break now", accent: true, action: manager.endBreak)
            MenuRow("Restart this break", action: manager.restartBreak)
        } else if manager.isPaused {
            MenuRow("Resume", accent: true, action: manager.resume)
        } else {
            MenuRow("Start break now", accent: true, action: manager.startBreak)
            if settings.allowSkip {
                MenuRow("Skip next break", action: manager.skipBreak)
            }
            MenuRow("Pause", trailing: showingPauseOptions ? "chevron.up" : "chevron.down") {
                withAnimation(Theme.Motion.settle) { showingPauseOptions.toggle() }
            }

            if showingPauseOptions {
                VStack(alignment: .leading, spacing: 0) {
                    MenuRow("For 30 minutes", inset: true) { pause(for: 30 * 60) }
                    MenuRow("For 1 hour", inset: true) { pause(for: 3600) }
                    MenuRow("Until tomorrow", inset: true) {
                        showingPauseOptions = false
                        manager.pauseUntilTomorrow()
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }

        MenuRow("Start fresh session", action: manager.startFreshSession)
    }

    private func pause(for interval: TimeInterval) {
        showingPauseOptions = false
        manager.pause(for: interval)
    }

    // MARK: - Footer

    private var footer: some View {
        VStack(alignment: .leading, spacing: 0) {
            SettingsLink {
                MenuRowLabel("Settings", trailing: nil, inset: false)
            }
            .buttonStyle(.plain)

            MenuRow("Quit StepAway") {
                NSApplication.shared.terminate(nil)
            }
        }
    }
}

// MARK: - Rows

private struct MenuRow: View {
    let title: String
    var trailing: String?
    var inset = false
    var accent = false
    let action: () -> Void

    init(
        _ title: String, trailing: String? = nil,
        inset: Bool = false, accent: Bool = false, action: @escaping () -> Void
    ) {
        self.title = title
        self.trailing = trailing
        self.inset = inset
        self.accent = accent
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            MenuRowLabel(title, trailing: trailing, inset: inset, accent: accent)
        }
        .buttonStyle(.plain)
    }
}

private struct MenuRowLabel: View {
    let title: String
    let trailing: String?
    let inset: Bool
    var accent = false

    @State private var hovering = false

    init(_ title: String, trailing: String?, inset: Bool, accent: Bool = false) {
        self.title = title
        self.trailing = trailing
        self.inset = inset
        self.accent = accent
    }

    private var foreground: Color {
        if hovering { return Theme.Palette.ink }
        if accent { return Theme.Palette.ink.opacity(0.92) }
        return inset ? Theme.Palette.ink.opacity(0.38) : Theme.Palette.inkMuted
    }

    var body: some View {
        HStack(spacing: 9) {
            if inset {
                Rectangle()
                    .fill(Theme.Palette.ink.opacity(hovering ? 0.34 : 0.14))
                    .frame(width: 12, height: 1)
            }

            Text(title)
                .microLabel(11, tracking: 0.10, emphasis: accent)
                .foregroundStyle(foreground)

            Spacer(minLength: 0)

            if let trailing {
                Image(systemName: trailing)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(Theme.Palette.hairline)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background {
            Capsule().fill(
                hovering
                    ? Color.white.opacity(0.08)
                    : (accent ? Color.white.opacity(0.045) : .clear)
            )
        }
        .contentShape(.capsule)
        .onHover { hovering = $0 }
        .animation(Theme.Motion.quick, value: hovering)
    }
}
