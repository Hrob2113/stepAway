import CoreGraphics
import SwiftUI

enum Grain {
    static let tile: Image = {
        let side = 160
        let bytes = side * side * 4
        var pixels = [UInt8](repeating: 255, count: bytes)
        var seed: UInt64 = 0x9E3779B97F4A7C15

        for index in stride(from: 0, to: bytes, by: 4) {
            seed ^= seed << 13
            seed ^= seed >> 7
            seed ^= seed << 17
            let value = UInt8(truncatingIfNeeded: seed >> 40)
            pixels[index] = value
            pixels[index + 1] = value
            pixels[index + 2] = value
        }

        guard let provider = CGDataProvider(data: Data(pixels) as CFData),
              let image = CGImage(
                  width: side, height: side,
                  bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: side * 4,
                  space: CGColorSpaceCreateDeviceRGB(),
                  bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                  provider: provider, decode: nil,
                  shouldInterpolate: false, intent: .defaultIntent
              )
        else { return Image(systemName: "circle") }

        return Image(decorative: image, scale: 2)
    }()
}

struct FilmGrain: View {
    var intensity: Double = 0.10

    var body: some View {
        Grain.tile
            .resizable(resizingMode: .tile)
            .opacity(intensity)
            .blendMode(.overlay)
            .allowsHitTesting(false)
    }
}

struct AmberBloom: View {
    var intensity: Double = 1
    var animated = true

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 20.0)) { timeline in
            let t = animated ? timeline.date.timeIntervalSinceReferenceDate : 0
            GeometryReader { geo in
                let reach = max(geo.size.width, geo.size.height)
                ZStack {
                    ForEach(Array(Light.all.enumerated()), id: \.offset) { _, light in
                        RadialGradient(
                            gradient: Gradient(stops: light.stops(intensity)),
                            center: light.centre(at: t),
                            startRadius: 0,
                            endRadius: reach * light.reach
                        )
                    }
                }
            }
        }
        .allowsHitTesting(false)
    }

    private struct Light {
        let anchor: UnitPoint
        let reach: CGFloat
        let drift: CGFloat
        let speed: Double
        let phase: Double
        let core: Color
        let body: Color
        let edge: Color
        let strength: Double

        func centre(at t: TimeInterval) -> UnitPoint {
            UnitPoint(
                x: anchor.x + drift * CGFloat(sin(t * speed + phase)),
                y: anchor.y + drift * 0.7 * CGFloat(cos(t * speed * 0.78 + phase))
            )
        }

        func stops(_ intensity: Double) -> [Gradient.Stop] {
            [
                .init(color: core.opacity(0.30 * strength * intensity), location: 0),
                .init(color: body.opacity(0.34 * strength * intensity), location: 0.26),
                .init(color: edge.opacity(0.16 * strength * intensity), location: 0.56),
                .init(color: edge.opacity(0), location: 1)
            ]
        }

        static let cream = Color(.sRGB, red: 1.00, green: 0.855, blue: 0.635)
        static let flame = Color(.sRGB, red: 0.910, green: 0.376, blue: 0.122)

        static let all: [Light] = [
            Light(anchor: UnitPoint(x: 0.26, y: 0.02), reach: 0.62, drift: 0.05,
                  speed: 0.08, phase: 0,
                  core: cream, body: flame, edge: Theme.Palette.ember, strength: 1.0),
            Light(anchor: UnitPoint(x: 0.82, y: 0.88), reach: 0.42, drift: 0.04,
                  speed: 0.06, phase: 2.4,
                  core: flame, body: Theme.Palette.ember, edge: Theme.Palette.ember, strength: 0.62),
            Light(anchor: UnitPoint(x: 0.06, y: 0.72), reach: 0.48, drift: 0.045,
                  speed: 0.05, phase: 4.1,
                  core: Theme.Palette.depth, body: Theme.Palette.depth,
                  edge: Theme.Palette.depth, strength: 0.55)
        ]
    }
}
