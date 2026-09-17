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

struct EyeGlyph: View {
    var tint: Color = Theme.Palette.ink
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

    private func openness(at t: TimeInterval) -> Double {
        guard animated else { return 1 }
        let period = 5.2
        let span = 0.38
        let cycle = t.truncatingRemainder(dividingBy: period)
        guard cycle < span else { return 1 }
        let u = cycle / span
        let blink = u < 0.38 ? smooth(u / 0.38) : smooth(1 - (u - 0.38) / 0.62)
        return 1 - blink * 0.96
    }

    private func draw(in ctx: GraphicsContext, size: CGSize, t: TimeInterval, look: CGPoint) {
        let w = size.width, h = size.height
        guard w > 2, h > 2 else { return }

        let cx = w / 2, cy = h / 2
        let halfW = w * 0.48
        let open = openness(at: t)

        guard open > 0.07 else {
            var lash = Path()
            lash.move(to: CGPoint(x: cx - halfW, y: cy))
            lash.addLine(to: CGPoint(x: cx + halfW, y: cy))
            ctx.stroke(
                lash, with: .color(tint),
                style: StrokeStyle(lineWidth: max(1.4, h * 0.05), lineCap: .round)
            )
            return
        }

        let halfH = h * 0.47 * open
        let lid = { (u: CGFloat) -> CGFloat in
            let s = 1 - u * u
            return s <= 0 ? 0 : halfH * CGFloat(pow(Double(s), 0.85))
        }

        let outline = Path { path in
            let steps = 72
            for i in 0...steps {
                let u = CGFloat(i) / CGFloat(steps) * 2 - 1
                let point = CGPoint(x: cx + u * halfW, y: cy - lid(u))
                if i == 0 { path.move(to: point) } else { path.addLine(to: point) }
            }
            for i in stride(from: steps, through: 0, by: -1) {
                let u = CGFloat(i) / CGFloat(steps) * 2 - 1
                path.addLine(to: CGPoint(x: cx + u * halfW, y: cy + lid(u)))
            }
            path.closeSubpath()
        }

        let irisR = max(1, min(halfH * 0.74, w * 0.145))
        let ix = cx + look.x * (halfW - irisR * 1.35) * 0.55
        let iy = cy - look.y * max(0, halfH - irisR) * 0.7

        var body = ctx
        body.clip(to: outline)
        body.fill(outline, with: .color(tint))

        let core = irisR * 0.72
        body.fill(
            Path(ellipseIn: CGRect(x: ix - core, y: iy - core, width: core * 2, height: core * 2)),
            with: .color(.black.opacity(0.95))
        )

        let unit = max(0.55, min(w, h) * 0.011)
        let count = max(140, min(Self.specks.count, Int(w * h * 0.55)))

        var shadow = Path()
        var halo = Path()

        for speck in Self.specks.prefix(count) {
            let px = speck.x * w
            let py = speck.y * h
            let u = (px - cx) / halfW
            guard abs(u) < 1.4 else { continue }

            let edge = lid(u)
            guard edge > 0.001 else { continue }
            let d = Double(abs(py - cy) / edge)

            if d <= 1 {
                let toIris = Double(hypot(px - ix, py - iy) / irisR)
                let ramp = (1 - Double(speck.x)) * 0.42 + Double(speck.y) * 0.58
                let chance = toIris < 1.45
                    ? 1 - smooth((toIris - 0.66) / 0.62)
                    : 0.58 * pow(d, 3.0) + 0.46 * ramp - 0.21
                if speck.roll < chance {
                    shadow.addEllipse(in: Self.dot(px, py, unit * speck.scale))
                }
            } else if d < 1.45 {
                if speck.roll < 0.46 * (1 - (d - 1) / 0.45) {
                    halo.addEllipse(in: Self.dot(px, py, unit * speck.scale * 0.8))
                }
            }
        }

        body.fill(shadow, with: .color(.black.opacity(0.94)))
        ctx.fill(halo, with: .color(tint))
    }

    private static func dot(_ x: CGFloat, _ y: CGFloat, _ side: CGFloat) -> CGRect {
        CGRect(x: x - side / 2, y: y - side / 2, width: side, height: side)
    }

    private struct Speck {
        let x: CGFloat
        let y: CGFloat
        let roll: Double
        let scale: CGFloat
    }

    private static let specks: [Speck] = {
        var seed: UInt64 = 0xD1B54A32D192ED03
        func next() -> Double {
            seed ^= seed << 13
            seed ^= seed >> 7
            seed ^= seed << 17
            return Double(seed >> 11) * (1.0 / 9007199254740992.0)
        }
        return (0..<5600).map { _ in
            Speck(x: CGFloat(next()), y: CGFloat(next()), roll: next(), scale: 0.5 + CGFloat(next()))
        }
    }()
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
