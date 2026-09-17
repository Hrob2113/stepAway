import SwiftUI

struct HourglassGlyph: View {
    var progress: Double
    var tint: Color = Theme.Palette.chalk
    var glass: Color = Theme.Palette.ink
    var animated: Bool = true

    var body: some View {
        if animated {
            TimelineView(.animation) { timeline in
                canvas(at: timeline.date.timeIntervalSinceReferenceDate)
            }
        } else {
            canvas(at: 0)
        }
    }

    private func canvas(at time: TimeInterval) -> some View {
        Canvas { ctx, size in
            let g = Geometry(size: size)
            let drained = min(max(progress, 0), 1)

            ctx.fill(g.topBulb, with: .color(glass.opacity(0.04)))
            ctx.fill(g.bottomBulb, with: .color(glass.opacity(0.04)))

            drawTopSand(ctx, g, drained)
            drawBottomSand(ctx, g, drained)
            if drained > 0.001, drained < 0.999 {
                drawStream(ctx, g, drained, time: time)
            }

            ctx.stroke(g.topBulb, with: .color(glass.opacity(0.30)), lineWidth: g.line)
            ctx.stroke(g.bottomBulb, with: .color(glass.opacity(0.30)), lineWidth: g.line)
            for cap in g.caps {
                ctx.fill(cap, with: .color(glass.opacity(0.42)))
            }
        }
    }

    // MARK: - Sand

    private func drawTopSand(_ ctx: GraphicsContext, _ g: Geometry, _ drained: Double) {
        let surface = g.topY + (g.neckY - g.topY) * drained
        guard surface < g.neckY - 0.5 else { return }

        let dip = min(g.size.width * 0.09, (g.neckY - surface) * 0.45) * drained
        var layer = ctx
        layer.clip(to: Path { p in
            p.move(to: CGPoint(x: 0, y: surface))
            p.addQuadCurve(
                to: CGPoint(x: g.size.width, y: surface),
                control: CGPoint(x: g.centerX, y: surface + dip * 2)
            )
            p.addLine(to: CGPoint(x: g.size.width, y: g.neckY))
            p.addLine(to: CGPoint(x: 0, y: g.neckY))
            p.closeSubpath()
        })
        layer.fill(g.topBulb, with: .linearGradient(
            Gradient(colors: [tint.opacity(0.75), tint]),
            startPoint: CGPoint(x: 0, y: surface),
            endPoint: CGPoint(x: 0, y: g.neckY)
        ))
    }

    private func drawBottomSand(_ ctx: GraphicsContext, _ g: Geometry, _ drained: Double) {
        let level = g.bottomY - (g.bottomY - g.neckY) * drained
        guard level < g.bottomY else { return }

        let mound = min(g.size.width * 0.085, (g.bottomY - level) * 0.38)
        var layer = ctx
        layer.clip(to: Path { p in
            p.move(to: CGPoint(x: 0, y: level + mound))
            p.addQuadCurve(
                to: CGPoint(x: g.size.width, y: level + mound),
                control: CGPoint(x: g.centerX, y: level - mound)
            )
            p.addLine(to: CGPoint(x: g.size.width, y: g.bottomY))
            p.addLine(to: CGPoint(x: 0, y: g.bottomY))
            p.closeSubpath()
        })
        layer.fill(g.bottomBulb, with: .linearGradient(
            Gradient(colors: [tint, tint.opacity(0.72)]),
            startPoint: CGPoint(x: 0, y: level),
            endPoint: CGPoint(x: 0, y: g.bottomY)
        ))
    }

    private func drawStream(_ ctx: GraphicsContext, _ g: Geometry, _ drained: Double, time: TimeInterval) {
        let landing = g.bottomY - (g.bottomY - g.neckY) * drained
        let fall = max(1, landing - g.neckY)

        ctx.fill(
            Path(CGRect(
                x: g.centerX - g.line * 0.28, y: g.neckY,
                width: g.line * 0.56, height: fall
            )),
            with: .linearGradient(
                Gradient(colors: [tint, tint.opacity(0.35)]),
                startPoint: CGPoint(x: 0, y: g.neckY),
                endPoint: CGPoint(x: 0, y: landing)
            )
        )

        guard animated else { return }
        for i in 0..<5 {
            let phase = (time * 1.45 + Double(i) / 5).truncatingRemainder(dividingBy: 1)
            let eased = phase * phase
            let y = g.neckY + fall * eased
            let sway = sin(phase * .pi * 2 + Double(i) * 1.3) * g.line * 0.16
            let r = g.line * (0.30 + 0.16 * abs(sin(Double(i) * 1.7)))
            ctx.fill(
                Path(ellipseIn: CGRect(
                    x: g.centerX + sway - r, y: y - r, width: r * 2, height: r * 2
                )),
                with: .color(tint.opacity(0.95 - eased * 0.35))
            )
        }
    }

    // MARK: - Geometry

    private struct Geometry {
        let size: CGSize
        let centerX: CGFloat
        let topY: CGFloat
        let bottomY: CGFloat
        let neckY: CGFloat
        let line: CGFloat
        let topBulb: Path
        let bottomBulb: Path
        let caps: [Path]

        init(size: CGSize) {
            let w = size.width, h = size.height
            let cx = w / 2
            let stroke = max(1.5, w * 0.045)
            let capHeight = h * 0.045
            let ty = capHeight
            let by = h - capHeight
            let ny = h / 2
            let halfW = w * 0.40
            let neckHalf = w * 0.035
            let bulge: CGFloat = 0.62

            let top = Path { p in
                p.move(to: CGPoint(x: cx - halfW, y: ty))
                p.addLine(to: CGPoint(x: cx + halfW, y: ty))
                p.addQuadCurve(
                    to: CGPoint(x: cx + neckHalf, y: ny),
                    control: CGPoint(x: cx + halfW * 0.95, y: ty + (ny - ty) * bulge)
                )
                p.addLine(to: CGPoint(x: cx - neckHalf, y: ny))
                p.addQuadCurve(
                    to: CGPoint(x: cx - halfW, y: ty),
                    control: CGPoint(x: cx - halfW * 0.95, y: ty + (ny - ty) * bulge)
                )
                p.closeSubpath()
            }

            let bottom = Path { p in
                p.move(to: CGPoint(x: cx - halfW, y: by))
                p.addLine(to: CGPoint(x: cx + halfW, y: by))
                p.addQuadCurve(
                    to: CGPoint(x: cx + neckHalf, y: ny),
                    control: CGPoint(x: cx + halfW * 0.95, y: by - (by - ny) * bulge)
                )
                p.addLine(to: CGPoint(x: cx - neckHalf, y: ny))
                p.addQuadCurve(
                    to: CGPoint(x: cx - halfW, y: by),
                    control: CGPoint(x: cx - halfW * 0.95, y: by - (by - ny) * bulge)
                )
                p.closeSubpath()
            }

            let capW = halfW * 2.14
            let capPaths = [ty, by].map { y in
                Path(roundedRect: CGRect(
                    x: cx - capW / 2, y: y - capHeight / 2,
                    width: capW, height: capHeight
                ), cornerRadius: capHeight / 2)
            }

            self.size = size
            centerX = cx
            topY = ty
            bottomY = by
            neckY = ny
            line = stroke
            topBulb = top
            bottomBulb = bottom
            caps = capPaths
        }
    }
}
