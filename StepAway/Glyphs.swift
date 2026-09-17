import AppKit
import SwiftUI

private func lerp(_ a: CGFloat, _ b: CGFloat, _ t: Double) -> CGFloat {
    a + (b - a) * CGFloat(t)
}

private func smooth(_ x: Double) -> Double {
    let t = min(max(x, 0), 1)
    return t * t * (3 - 2 * t)
}

private struct WindowReader: NSViewRepresentable {
    @Binding var window: NSWindow?

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async { window = view.window }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            if window !== nsView.window { window = nsView.window }
        }
    }
}

private final class GazeTracker {
    var current: CGPoint = .zero

    func step(toward target: CGPoint, rate: CGFloat) {
        current.x += (target.x - current.x) * rate
        current.y += (target.y - current.y) * rate
    }
}

struct EyesGlyph: View {
    var tint: Color = Theme.Palette.chalk
    var animated = true

    @State private var window: NSWindow?
    @State private var gaze = GazeTracker()

    var body: some View {
        GeometryReader { geo in
            TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { timeline in
                Canvas { ctx, size in
                    let t = animated ? timeline.date.timeIntervalSinceReferenceDate : 0
                    if animated {
                        gaze.step(toward: target(geo), rate: 0.10)
                    }
                    draw(in: ctx, size: size, t: t, look: gaze.current)
                }
            }
        }
        .background(WindowReader(window: $window))
    }

    private func target(_ geo: GeometryProxy) -> CGPoint {
        guard let window else { return .zero }
        let inWindow = geo.frame(in: .global)
        let frame = window.frame
        let centre = CGPoint(x: frame.minX + inWindow.midX, y: frame.maxY - inWindow.midY)
        let mouse = NSEvent.mouseLocation
        let reach: CGFloat = 480
        return CGPoint(
            x: max(-1, min(1, (mouse.x - centre.x) / reach)),
            y: max(-1, min(1, (mouse.y - centre.y) / reach))
        )
    }

    private func draw(in ctx: GraphicsContext, size: CGSize, t: TimeInterval, look: CGPoint) {
        let w = size.width, h = size.height
        let stroke = max(1.5, w * 0.035)

        let period = 5.2
        let cycle = t.truncatingRemainder(dividingBy: period)
        let span = 0.38
        var blink = 0.0
        if animated, cycle < span {
            let u = cycle / span
            blink = u < 0.38 ? smooth(u / 0.38) : smooth(1 - (u - 0.38) / 0.62)
        }
        let openness = 1 - blink * 0.96

        let eyeW = w * 0.36
        let eyeH = h * 0.145 * openness
        let centres = [CGPoint(x: w * 0.26, y: h * 0.5), CGPoint(x: w * 0.74, y: h * 0.5)]

        for c in centres {
            let lid = Path { p in
                p.move(to: CGPoint(x: c.x - eyeW / 2, y: c.y))
                p.addQuadCurve(
                    to: CGPoint(x: c.x + eyeW / 2, y: c.y),
                    control: CGPoint(x: c.x, y: c.y - eyeH * 1.85)
                )
                p.addQuadCurve(
                    to: CGPoint(x: c.x - eyeW / 2, y: c.y),
                    control: CGPoint(x: c.x, y: c.y + eyeH * 1.85)
                )
                p.closeSubpath()
            }

            if openness > 0.22 {
                var inner = ctx
                inner.clip(to: lid)
                let r = min(eyeW * 0.22, h * 0.085)
                let ix = c.x + look.x * eyeW * 0.26
                let iy = c.y - look.y * h * 0.055
                inner.fill(
                    Path(ellipseIn: CGRect(x: ix - r, y: iy - r, width: r * 2, height: r * 2)),
                    with: .color(tint.opacity(0.92))
                )
            }
            ctx.stroke(lid, with: .color(tint), lineWidth: stroke)
        }
    }
}

struct StretchGlyph: View {
    var tint: Color = Theme.Palette.chalk
    var animated = true

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { timeline in
            Canvas { ctx, size in
                let t = animated ? timeline.date.timeIntervalSinceReferenceDate : 1.6
                let raw = (sin(t * 0.7 - .pi / 2) + 1) / 2
                draw(in: ctx, size: size, p: raw * raw * (3 - 2 * raw))
            }
        }
    }

    private func draw(in ctx: GraphicsContext, size: CGSize, p: Double) {
        let w = size.width, h = size.height
        let stroke = max(1.8, w * 0.055)
        let style = StrokeStyle(lineWidth: stroke, lineCap: .round, lineJoin: .round)

        let headR = w * 0.11
        let headY = lerp(h * 0.34, h * 0.17, p)
        let neck = CGPoint(x: w * 0.5, y: headY + headR * 1.25)
        let hip = CGPoint(x: w * 0.5, y: lerp(h * 0.64, h * 0.58, p))

        ctx.stroke(
            Path(ellipseIn: CGRect(
                x: w * 0.5 - headR, y: headY - headR, width: headR * 2, height: headR * 2
            )),
            with: .color(tint), lineWidth: stroke
        )
        ctx.stroke(Path { $0.move(to: neck); $0.addLine(to: hip) }, with: .color(tint), style: style)

        for side in [-1.0, 1.0] {
            let hand = CGPoint(
                x: lerp(w * (0.5 + 0.20 * side), w * (0.5 + 0.30 * side), p),
                y: lerp(h * 0.56, h * 0.13, p)
            )
            let elbow = CGPoint(
                x: lerp(w * (0.5 + 0.19 * side), w * (0.5 + 0.28 * side), p),
                y: lerp(h * 0.47, h * 0.30, p)
            )
            ctx.stroke(Path { path in
                path.move(to: neck)
                path.addLine(to: elbow)
                path.addLine(to: hand)
            }, with: .color(tint), style: style)
        }

        for side in [-1.0, 1.0] {
            let knee = CGPoint(
                x: lerp(w * (0.5 + 0.22 * side), w * (0.5 + 0.10 * side), p),
                y: lerp(h * 0.70, h * 0.76, p)
            )
            let foot = CGPoint(
                x: lerp(w * (0.5 + 0.24 * side), w * (0.5 + 0.11 * side), p),
                y: h * 0.90
            )
            ctx.stroke(Path { path in
                path.move(to: hip)
                path.addLine(to: knee)
                path.addLine(to: foot)
            }, with: .color(tint), style: style)
        }
    }
}

struct PostureGlyph: View {
    var tint: Color = Theme.Palette.chalk
    var animated = true

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { timeline in
            Canvas { ctx, size in
                let t = animated ? timeline.date.timeIntervalSinceReferenceDate : 1.0
                let raw = (sin(t * 0.8 - .pi / 2) + 1) / 2
                draw(in: ctx, size: size, p: raw * raw * (3 - 2 * raw))
            }
        }
    }

    private func draw(in ctx: GraphicsContext, size: CGSize, p: Double) {
        let w = size.width, h = size.height
        let stroke = max(1.8, w * 0.065)
        let style = StrokeStyle(lineWidth: stroke, lineCap: .round, lineJoin: .round)

        let hip = CGPoint(x: w * 0.32, y: h * 0.66)
        let knee = CGPoint(x: w * 0.74, y: h * 0.66)
        let foot = CGPoint(x: w * 0.74, y: h * 0.92)

        let headR = w * 0.105
        let headC = CGPoint(x: lerp(w * 0.58, w * 0.34, p), y: lerp(h * 0.36, h * 0.20, p))
        let neck = CGPoint(x: headC.x, y: headC.y + headR * 1.35)

        ctx.stroke(Path { path in
            path.move(to: hip)
            path.addLine(to: knee)
            path.addLine(to: foot)
        }, with: .color(tint), style: style)

        ctx.stroke(Path { path in
            path.move(to: hip)
            path.addQuadCurve(
                to: neck,
                control: CGPoint(x: lerp(w * 0.58, w * 0.30, p), y: h * 0.50)
            )
        }, with: .color(tint), style: style)

        ctx.stroke(
            Path(ellipseIn: CGRect(
                x: headC.x - headR, y: headC.y - headR, width: headR * 2, height: headR * 2
            )),
            with: .color(tint), lineWidth: stroke
        )
    }
}
