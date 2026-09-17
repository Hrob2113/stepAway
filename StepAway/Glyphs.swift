import AppKit
import SwiftUI

private func lerp(_ a: CGFloat, _ b: CGFloat, _ t: Double) -> CGFloat {
    a + (b - a) * CGFloat(t)
}

private func smooth(_ x: Double) -> Double {
    let t = min(max(x, 0), 1)
    return t * t * (3 - 2 * t)
}

private final class Gaze {
    private(set) var current: CGPoint = .zero

    private var from: CGPoint = .zero
    private var to: CGPoint = .zero
    private var startedAt: TimeInterval = 0
    private var duration: TimeInterval = 0.1
    private var settleUntil: TimeInterval = 0
    private var started = false

    func step(at t: TimeInterval, lidsDown: Bool) {
        if !started {
            started = true
            startedAt = t
            settleUntil = t + 0.6
        }

        let arrived = t >= startedAt + duration
        let restless = t >= settleUntil
        let glancesAway = lidsDown && arrived && Double.random(in: 0...1) < 0.06

        if arrived, restless || glancesAway {
            from = current
            to = Self.somewhere(avoiding: to)
            let reach = Double(hypot(to.x - from.x, to.y - from.y))
            duration = glancesAway ? 0.04 : 0.055 + reach * 0.075
            startedAt = t
            settleUntil = t + duration + .random(in: 0.55...2.4)
        }

        let travel = duration > 0 ? min(1, max(0, (t - startedAt) / duration)) : 1
        let eased = travel * travel * travel * (travel * (travel * 6 - 15) + 10)
        current = CGPoint(
            x: lerp(from.x, to.x, eased) + CGFloat(sin(t * 1.7) * 0.011),
            y: lerp(from.y, to.y, eased) + CGFloat(cos(t * 1.27) * 0.009)
        )
    }

    private static func somewhere(avoiding previous: CGPoint) -> CGPoint {
        for _ in 0..<4 {
            let candidate = Double.random(in: 0...1) < 0.28
                ? CGPoint(x: .random(in: -0.16...0.16), y: .random(in: -0.12...0.12))
                : CGPoint(x: .random(in: -0.86...0.86), y: .random(in: -0.5...0.5))
            if hypot(candidate.x - previous.x, candidate.y - previous.y) > 0.3 { return candidate }
        }
        return CGPoint(x: .random(in: -0.8...0.8), y: .random(in: -0.45...0.45))
    }
}

struct EyeGlyph: View {
    var tint: Color = Theme.Palette.ink
    var animated = true

    @State private var gaze = Gaze()

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { timeline in
            Canvas { ctx, size in
                let t = animated ? timeline.date.timeIntervalSinceReferenceDate : 0
                if animated {
                    gaze.step(at: t, lidsDown: openness(at: t) < 0.3)
                }
                draw(in: ctx, size: size, t: t, look: gaze.current)
            }
        }
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

struct MenuBarEyeIcon: View {
    let resting: Bool
    let paused: Bool

    @State private var lid = 1.0
    @State private var gaze = 0.0

    private static let size = NSSize(width: 20, height: 13)
    private static var cache: [Frame: NSImage] = [:]

    private struct Frame: Hashable {
        let lid: Int
        let gaze: Int
    }

    var body: some View {
        Image(nsImage: icon())
            .task { await live() }
    }

    private func live() async {
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(.random(in: 3.8...7.2)))
            guard !resting, !paused else { continue }

            let steps = 9
            for step in 0...steps {
                let u = Double(step) / Double(steps)
                lid = 1 - (u < 0.38 ? smooth(u / 0.38) : smooth(1 - (u - 0.38) / 0.62)) * 0.96
                if step == 5 { gaze = .random(in: -0.7...0.7) }
                try? await Task.sleep(for: .milliseconds(40))
            }
            lid = 1
        }
    }

    private func icon() -> NSImage {
        let open = resting ? 0 : (paused ? 0.62 : lid)
        let frame = Frame(
            lid: Int((open * 12).rounded()),
            gaze: resting || paused ? 0 : Int((gaze * 10).rounded())
        )
        if let cached = Self.cache[frame] { return cached }

        let image = NSImage(size: Self.size)
        image.lockFocus()
        draw(open: Double(frame.lid) / 12, gaze: CGFloat(frame.gaze) / 10)
        image.unlockFocus()
        image.isTemplate = true

        Self.cache[frame] = image
        return image
    }

    private func draw(open: Double, gaze: CGFloat) {
        let w = Self.size.width, h = Self.size.height
        let cx = w / 2, cy = h / 2
        let halfW = w / 2 - 1

        NSColor.black.setStroke()
        NSColor.black.setFill()

        guard open > 0.14 else {
            let lash = NSBezierPath()
            lash.move(to: NSPoint(x: cx - halfW, y: cy))
            lash.line(to: NSPoint(x: cx + halfW, y: cy))
            lash.lineWidth = 1.4
            lash.lineCapStyle = .round
            lash.stroke()
            return
        }

        let halfH = (h / 2 - 1) * open
        let almond = NSBezierPath()
        let steps = 40
        for i in 0...steps {
            let u = CGFloat(i) / CGFloat(steps) * 2 - 1
            let point = NSPoint(x: cx + u * halfW, y: cy + lidHeight(u, halfH))
            if i == 0 { almond.move(to: point) } else { almond.line(to: point) }
        }
        for i in stride(from: steps, through: 0, by: -1) {
            let u = CGFloat(i) / CGFloat(steps) * 2 - 1
            almond.line(to: NSPoint(x: cx + u * halfW, y: cy - lidHeight(u, halfH)))
        }
        almond.close()
        almond.lineWidth = 1.2
        almond.lineJoinStyle = .round
        almond.stroke()

        let r = min(halfH * 0.66, w * 0.15)
        let ix = cx + gaze * max(0, halfW - r * 2.1)
        NSBezierPath(
            ovalIn: NSRect(x: ix - r, y: cy - r, width: r * 2, height: r * 2)
        ).fill()
    }

    private func lidHeight(_ u: CGFloat, _ halfH: CGFloat) -> CGFloat {
        let s = 1 - u * u
        return s <= 0 ? 0 : halfH * CGFloat(pow(Double(s), 0.85))
    }
}
