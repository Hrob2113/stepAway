import SwiftUI

struct MenuBarContentView: View {
    let manager: BreakManager
    let settings: AppSettings

    @State private var showingPauseOptions = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            status
            Divider().padding(.vertical, 6)
            actions
            Divider().padding(.vertical, 6)
            footer
        }
        .padding(10)
        .frame(width: 268)
        .background(BackdropBlur(material: .fullScreenUI))
        .overlay(alignment: .top) {
            LinearGradient(
                colors: [Color.white.opacity(0.13), .clear],
                startPoint: .top, endPoint: .bottom
            )
            .frame(height: 90)
            .allowsHitTesting(false)
        }
    }

    // MARK: - Status

    private var status: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 11) {
                Group {
                    if manager.isPaused {
                        Image(systemName: "pause.circle.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(Theme.Palette.chalk)
                    } else {
                        HourglassGlyph(progress: manager.progress)
                    }
                }
                .frame(width: 23, height: 31)

                VStack(alignment: .leading, spacing: 2) {
                    Text(manager.statusHeadline)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.Palette.ink)
                    if !manager.isPaused, !manager.cycleProgress.isEmpty {
                        Text(manager.cycleProgress)
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.Palette.inkMuted)
                    }
                }
                Spacer(minLength: 0)
            }

            if !manager.isPaused {
                Capsule()
                    .fill(Color.white.opacity(0.12))
                    .frame(height: 5)
                    .overlay(alignment: .leading) {
                        GeometryReader { geo in
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Theme.Palette.chalk.opacity(0.55),
                                            Theme.Palette.chalk
                                        ],
                                        startPoint: .leading, endPoint: .trailing
                                    )
                                )
                                .frame(width: geo.size.width * manager.progress)
                                .animation(.linear(duration: 1), value: manager.progress)
                        }
                    }
            }
        }
        .padding(.horizontal, 8)
        .padding(.top, 4)
    }

    // MARK: - Actions

    @ViewBuilder
    private var actions: some View {
        if manager.isResting {
            MenuRow("Finish break now", icon: "checkmark.circle", accent: true, action: manager.endBreak)
            MenuRow("Restart this break", icon: "arrow.counterclockwise", action: manager.restartBreak)
        } else if manager.isPaused {
            MenuRow("Resume", icon: "play.circle", accent: true, action: manager.resume)
        } else {
            MenuRow("Start break now", icon: "play.circle", accent: true, action: manager.startBreak)
            if settings.allowSkip {
                MenuRow("Skip next break", icon: "forward.end", action: manager.skipBreak)
            }
            MenuRow(
                "Pause", icon: "pause.circle",
                trailing: showingPauseOptions ? "chevron.up" : "chevron.down"
            ) {
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

        MenuRow("Start fresh session", icon: "arrow.clockwise", action: manager.startFreshSession)
    }

    private func pause(for interval: TimeInterval) {
        showingPauseOptions = false
        manager.pause(for: interval)
    }

    // MARK: - Footer

    private var footer: some View {
        VStack(alignment: .leading, spacing: 0) {
            SettingsLink {
                MenuRowLabel("Settings", icon: "gearshape", trailing: nil, inset: false)
            }
            .buttonStyle(.plain)

            MenuRow("Quit StepAway", icon: "power") {
                NSApplication.shared.terminate(nil)
            }
        }
    }
}

// MARK: - Rows

private struct MenuRow: View {
    let title: String
    var icon: String?
    var trailing: String?
    var inset = false
    var accent = false
    let action: () -> Void

    init(
        _ title: String, icon: String? = nil, trailing: String? = nil,
        inset: Bool = false, accent: Bool = false, action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.trailing = trailing
        self.inset = inset
        self.accent = accent
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            MenuRowLabel(title, icon: icon, trailing: trailing, inset: inset, accent: accent)
        }
        .buttonStyle(.plain)
    }
}

private struct MenuRowLabel: View {
    let title: String
    let icon: String?
    let trailing: String?
    let inset: Bool
    var accent = false

    @State private var hovering = false

    init(_ title: String, icon: String?, trailing: String?, inset: Bool, accent: Bool = false) {
        self.title = title
        self.icon = icon
        self.trailing = trailing
        self.inset = inset
        self.accent = accent
    }

    var body: some View {
        HStack(spacing: 9) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .frame(width: 18)
                    .foregroundStyle(accent ? Theme.Palette.ink : Theme.Palette.inkMuted)
            } else if inset {
                Spacer().frame(width: 18)
            }

            Text(title)
                .font(.system(size: 13, weight: accent ? .semibold : .regular))
                .foregroundStyle(inset ? Theme.Palette.inkMuted : Theme.Palette.ink)

            Spacer(minLength: 0)

            if let trailing {
                Image(systemName: trailing)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Theme.Palette.hairline)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            Capsule().fill(
                hovering
                    ? Color.white.opacity(0.16)
                    : (accent ? Color.white.opacity(0.09) : .clear)
            )
        )
        .contentShape(.capsule)
        .onHover { hovering = $0 }
        .animation(Theme.Motion.quick, value: hovering)
    }
}
