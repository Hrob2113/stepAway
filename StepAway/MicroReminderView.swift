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
        HStack(spacing: 15) {
            glyph
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(Theme.rounded(16, .semibold))
                    .foregroundStyle(Theme.Palette.ink)
                Text(detail)
                    .font(Theme.rounded(13))
                    .foregroundStyle(Theme.Palette.inkMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .frame(width: 356, alignment: .leading)
        .frostedPanel(cornerRadius: 30)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : -18)
        .onAppear(perform: enter)
    }

    private var glyph: some View {
        Group {
            if kind == .posture {
                PostureGlyph(animated: !reduceMotion)
            } else {
                EyesGlyph(animated: !reduceMotion)
            }
        }
        .frame(width: 42, height: 36)
    }

    private func enter() {
        guard !reduceMotion else {
            appeared = true
            return
        }
        withAnimation(Theme.Motion.settle) { appeared = true }
    }
}
