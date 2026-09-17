import AppKit
import SwiftUI

enum Theme {
    enum Palette {
        static let glass = Color(white: 0.24)

        static let ink = Color(white: 0.97)
        static let inkMuted = Color(white: 0.70)
        static let chalk = Color(white: 0.90)
        static let hairline = Color(white: 0.45)
    }

    enum Motion {
        static let bloom  = Animation.smooth(duration: 0.85)
        static let settle = Animation.smooth(duration: 0.55, extraBounce: 0.12)
        static let quick  = Animation.snappy(duration: 0.26, extraBounce: 0.04)
        static let breathe = Animation.easeInOut(duration: 4).repeatForever(autoreverses: true)
    }

    static func rounded(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }

    static func counter(_ size: CGFloat) -> Font {
        .system(size: size, weight: .light, design: .rounded).monospacedDigit()
    }
}

extension TimeInterval {
    var clockText: String {
        let total = max(0, Int(rounded()))
        return total >= 60
            ? String(format: "%d:%02d", total / 60, total % 60)
            : "\(total)s"
    }

    var casualText: String {
        let total = max(0, Int(rounded()))
        if total >= 3600 { return "\(total / 3600) hr" }
        if total >= 60 { return "\(total / 60) min" }
        return "\(total) sec"
    }
}

// MARK: - Glass

struct BackdropBlur: NSViewRepresentable {
    var material: NSVisualEffectView.Material = .fullScreenUI
    var forcesDark = true

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.blendingMode = .behindWindow
        view.state = .active
        apply(to: view)
        return view
    }

    func updateNSView(_ view: NSVisualEffectView, context: Context) {
        apply(to: view)
    }

    private func apply(to view: NSVisualEffectView) {
        view.material = material
        view.appearance = forcesDark ? NSAppearance(named: .darkAqua) : nil
    }
}

extension View {
    func frostedPanel(cornerRadius: CGFloat = 30) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        return self
            .background(BackdropBlur(material: .fullScreenUI).clipShape(shape))
            .overlay {
                shape
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.16),
                                Color.white.opacity(0.03),
                                .clear
                            ],
                            startPoint: .top, endPoint: .center
                        )
                    )
                    .allowsHitTesting(false)
            }
            .overlay {
                shape.strokeBorder(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.50),
                            Color.white.opacity(0.12),
                            Color.white.opacity(0.06)
                        ],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
            }
            .shadow(color: .black.opacity(0.45), radius: 30, y: 14)
    }

    func glassCapsule(tint: Color, intensity: Double = 0.48) -> some View {
        self
            .glassEffect(.regular.tint(tint.opacity(intensity)), in: .capsule)
            .overlay {
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [Color.white.opacity(0.22), .clear],
                            startPoint: .top, endPoint: .center
                        )
                    )
                    .allowsHitTesting(false)
            }
            .overlay(Capsule().strokeBorder(Color.white.opacity(0.28), lineWidth: 1))
    }
}

struct DriftingOrbs: View {
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            Canvas { ctx, size in
                ctx.addFilter(.blur(radius: min(size.width, size.height) * 0.20))
                for orb in Orb.all {
                    let x = size.width * (orb.origin.x + 0.06 * sin(t * orb.speed + orb.phase))
                    let y = size.height * (orb.origin.y + 0.05 * cos(t * orb.speed * 0.8 + orb.phase))
                    let r = min(size.width, size.height) * orb.radius
                    ctx.fill(
                        Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)),
                        with: .color(orb.color.opacity(orb.opacity))
                    )
                }
            }
        }
        .allowsHitTesting(false)
    }

    private struct Orb {
        let origin: CGPoint
        let radius: CGFloat
        let color: Color
        let opacity: Double
        let speed: Double
        let phase: Double

        static let all: [Orb] = [
            Orb(origin: CGPoint(x: 0.24, y: 0.30), radius: 0.26,
                color: .white, opacity: 0.10, speed: 0.11, phase: 0),
            Orb(origin: CGPoint(x: 0.78, y: 0.26), radius: 0.20,
                color: .white, opacity: 0.06, speed: 0.14, phase: 1.9),
            Orb(origin: CGPoint(x: 0.66, y: 0.74), radius: 0.30,
                color: .black, opacity: 0.22, speed: 0.09, phase: 3.4),
            Orb(origin: CGPoint(x: 0.18, y: 0.80), radius: 0.18,
                color: .black, opacity: 0.18, speed: 0.13, phase: 5.1)
        ]
    }
}
