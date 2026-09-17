import SwiftUI

struct IdleReturnView: View {
    let manager: BreakManager

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionLabel("You stepped away")

            Text("Welcome back")
                .font(Theme.display(38, .black))
                .tracking(-0.5)
                .textCase(.uppercase)
                .foregroundStyle(Theme.Palette.ink)
                .padding(.top, 14)

            Text("You were away a while. Did your eyes get a rest?")
                .font(Theme.voice(16))
                .foregroundStyle(Theme.Palette.inkMuted)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 6)

            VStack(spacing: 9) {
                choice("Yes, start a new session", prominent: true, action: manager.creditIdleBreak)
                choice("No, keep my timer running", prominent: false, action: manager.dismissIdleReturn)
            }
            .padding(.top, 26)

            Brandmark()
                .opacity(0.7)
                .padding(.top, 20)
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 28)
        .frame(width: 356, height: 288, alignment: .topLeading)
        .glassPanel(cornerRadius: Theme.Radius.xl)
        .opacity(appeared ? 1 : 0)
        .scaleEffect(appeared ? 1 : 0.95)
        .onAppear {
            guard !reduceMotion else { appeared = true; return }
            withAnimation(Theme.Motion.settle) { appeared = true }
        }
    }

    private func choice(_ label: String, prominent: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .microLabel(10, tracking: 0.14, emphasis: prominent)
                .foregroundStyle(prominent ? Theme.Palette.ink : Theme.Palette.inkMuted)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .glassPill(prominent: prominent)
        }
        .buttonStyle(.plain)
    }
}
