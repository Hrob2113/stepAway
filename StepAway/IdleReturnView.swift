import SwiftUI

struct IdleReturnView: View {
    let manager: BreakManager

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    var body: some View {
        VStack(spacing: 0) {
            Image(systemName: "sun.horizon")
                .font(.system(size: 34, weight: .light))
                .foregroundStyle(Theme.Palette.chalk)
                .padding(.bottom, 18)

            Text("Welcome back")
                .font(Theme.rounded(22, .semibold))
                .foregroundStyle(Theme.Palette.ink)

            Text("You were away a while. Did your eyes get a rest?")
                .font(Theme.rounded(14))
                .foregroundStyle(Theme.Palette.inkMuted)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 7)

            VStack(spacing: 9) {
                choice("Yes, start a new session", prominent: true, action: manager.creditIdleBreak)
                choice("No, keep my timer running", prominent: false, action: manager.dismissIdleReturn)
            }
            .padding(.top, 24)
        }
        .padding(.horizontal, 26)
        .padding(.vertical, 28)
        .frame(width: 352, height: 258)
        .frostedPanel(cornerRadius: 36)
        .opacity(appeared ? 1 : 0)
        .scaleEffect(appeared ? 1 : 0.95)
        .onAppear {
            guard !reduceMotion else { appeared = true; return }
            withAnimation(Theme.Motion.settle) { appeared = true }
        }
    }

    @ViewBuilder
    private func choice(_ label: String, prominent: Bool, action: @escaping () -> Void) -> some View {
        if prominent {
            Button(action: action) {
                Text(label)
                    .font(Theme.rounded(13, .semibold))
                    .foregroundStyle(Theme.Palette.ink)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9)
                    .glassCapsule(tint: Theme.Palette.glass, intensity: 0.70)
            }
            .buttonStyle(.plain)
        } else {
            Button(action: action) {
                Text(label)
                    .font(Theme.rounded(13))
                    .foregroundStyle(Theme.Palette.inkMuted)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9)
                    .glassCapsule(tint: Theme.Palette.glass, intensity: 0.28)
            }
            .buttonStyle(.plain)
        }
    }
}
