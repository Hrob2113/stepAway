import SwiftUI

struct MicroReminderView: View {
    let kind: MicroReminder

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    private var title: String {
        kind == .posture ? "Sit tall" : "Blink a few times"
    }

    private var detail: String {
        kind == .posture
            ? "Lift your chest, drop your shoulders."
            : "Slow, soft blinks bring the moisture back."
    }

    var body: some View {
        HStack(spacing: 16) {
            glyph
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(Theme.display(21, .heavy))
                    .tracking(0.3)
                    .textCase(.uppercase)
                    .foregroundStyle(Theme.Palette.ink)
                Text(detail)
                    .font(Theme.voice(14))
                    .foregroundStyle(Theme.Palette.inkMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 17)
        .frame(width: 356, alignment: .leading)
        .glassPanel(cornerRadius: Theme.Radius.lg)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : -18)
        .onAppear(perform: enter)
    }

    private var glyph: some View {
        Group {
            if kind == .posture {
                PostureGlyph(animated: !reduceMotion)
            } else {
                EyeGlyph(animated: !reduceMotion)
            }
        }
        .frame(width: 50, height: 28)
    }

    private func enter() {
        guard !reduceMotion else {
            appeared = true
            return
        }
        withAnimation(Theme.Motion.settle) { appeared = true }
    }
}
