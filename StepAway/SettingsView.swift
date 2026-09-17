import SwiftUI

struct SettingsView: View {
    @Bindable var settings: AppSettings
    let manager: BreakManager

    var body: some View {
        TabView {
            GeneralTab(settings: settings)
                .tabItem { Label("General", systemImage: "gearshape") }
            TimersTab(settings: settings, manager: manager)
                .tabItem { Label("Timers", systemImage: "timer") }
        }
        .background {
            DesktopBlur(material: .hudWindow)
                .ignoresSafeArea()
        }
        .frame(width: 470, height: 520)
        .overlay(alignment: .bottom) { Brandmark().opacity(0.8).padding(.bottom, 12) }
        .tint(Theme.Palette.ink)
    }
}

private struct GlassForm<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        Form { content }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
            .background {
                DesktopBlur(material: .hudWindow)
                    .ignoresSafeArea()
            }
    }
}

// MARK: - General

private struct GeneralTab: View {
    @Bindable var settings: AppSettings

    var body: some View {
        GlassForm {
            Section("Rhythm") {
                ForEach([Preset.balanced, .relaxed, .intensive]) { preset in
                    PresetRow(
                        preset: preset,
                        selected: settings.preset == preset,
                        action: { settings.apply(preset) }
                    )
                }
                if settings.preset == .custom {
                    Label(Preset.custom.detail, systemImage: "slider.horizontal.3")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }

            Section("During a break") {
                Toggle("Allow skipping breaks", isOn: $settings.allowSkip)
                Toggle("Play a sound when breaks start and end", isOn: $settings.soundEnabled)
            }

            Section("Warning") {
                Picker("Notify before a break", selection: $settings.preBreakWarning) {
                    Text("Don't notify").tag(TimeInterval(0))
                    Text("30 seconds").tag(TimeInterval(30))
                    Text("1 minute").tag(TimeInterval(60))
                    Text("2 minutes").tag(TimeInterval(120))
                    Text("5 minutes").tag(TimeInterval(300))
                }
            }

            Section("Nudges") {
                Toggle("Remind me to sit tall", isOn: $settings.postureRemindersOn)
                if settings.postureRemindersOn {
                    Picker("Every", selection: $settings.postureInterval) {
                        ForEach([5, 7, 10, 15, 20, 30], id: \.self) { m in
                            Text("\(m) minutes").tag(TimeInterval(m * 60))
                        }
                    }
                }

                Toggle("Remind me to blink", isOn: $settings.blinkRemindersOn)
                if settings.blinkRemindersOn {
                    Picker("Every", selection: $settings.blinkInterval) {
                        ForEach([10, 20, 30, 45, 60], id: \.self) { m in
                            Text("\(m) minutes").tag(TimeInterval(m * 60))
                        }
                    }
                }
            }
        }
    }
}

private struct PresetRow: View {
    let preset: Preset
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: selected ? "largecircle.fill.circle" : "circle")
                    .foregroundStyle(selected ? Theme.Palette.ink : Theme.Palette.hairline)
                    .font(.system(size: 14))

                VStack(alignment: .leading, spacing: 1) {
                    Text(preset.name)
                        .font(Theme.display(17, .heavy))
                        .textCase(.uppercase)
                        .tracking(0.4)
                    Text(preset.detail)
                        .font(Theme.voice(13))
                        .foregroundStyle(Theme.Palette.inkMuted)
                }
                Spacer(minLength: 0)
            }
            .padding(.vertical, 5)
            .padding(.horizontal, 9)
            .background(
                Capsule().fill(selected ? Color.white.opacity(0.10) : .clear)
            )
            .contentShape(.capsule)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Timers

private struct TimersTab: View {
    @Bindable var settings: AppSettings
    let manager: BreakManager

    var body: some View {
        GlassForm {
            Section("Work") {
                DurationRow(
                    title: "Work session", value: $settings.workDuration,
                    range: 5...90, step: 5, unit: .minutes
                )
            }

            Section("Breaks") {
                DurationRow(
                    title: "Short break", value: $settings.shortBreakDuration,
                    range: 10...180, step: 5, unit: .seconds
                )
                DurationRow(
                    title: "Long break", value: $settings.longBreakDuration,
                    range: 1...30, step: 1, unit: .minutes
                )
                Stepper(value: $settings.breaksBeforeLong, in: 2...8) {
                    LabeledContent("Long break after") {
                        Text("\(settings.breaksBeforeLong) short breaks")
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section {
                Button {
                    manager.startFreshSession()
                } label: {
                    Text("Reset the current session")
                        .microLabel(10, tracking: 0.14)
                        .foregroundStyle(Theme.Palette.ink)
                        .padding(.horizontal, 22)
                        .padding(.vertical, 10)
                        .glassPill()
                }
                .buttonStyle(.plain)
                Text("Starts the work timer over from the beginning.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct DurationRow: View {
    enum Unit {
        case minutes, seconds
        var scale: TimeInterval { self == .minutes ? 60 : 1 }
        var name: String { self == .minutes ? "min" : "sec" }
    }

    let title: String
    @Binding var value: TimeInterval
    let range: ClosedRange<Int>
    let step: Int
    let unit: Unit

    private var amount: Int { Int((value / unit.scale).rounded()) }

    var body: some View {
        Stepper(
            value: Binding(
                get: { amount },
                set: { value = TimeInterval($0) * unit.scale }
            ),
            in: range, step: step
        ) {
            LabeledContent(title) {
                Text("\(amount) \(unit.name)").foregroundStyle(.secondary)
            }
        }
    }
}
