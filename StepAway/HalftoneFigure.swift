import SwiftUI

struct HalftoneFigure {
    struct Bone {
        let a: CGPoint
        let b: CGPoint
        let radius: CGFloat

        func distance(to point: CGPoint) -> CGFloat {
            let span = CGPoint(x: b.x - a.x, y: b.y - a.y)
            let offset = CGPoint(x: point.x - a.x, y: point.y - a.y)
            let length = span.x * span.x + span.y * span.y
            let along = length > 0
                ? min(1, max(0, (offset.x * span.x + offset.y * span.y) / length))
                : 0
            return hypot(offset.x - span.x * along, offset.y - span.y * along) - radius
        }
    }

    struct Joint {
        let at: CGPoint
        let radius: CGFloat
    }

    let bones: [Bone]

    // MARK: - Field

    private static let edge: CGFloat = 0.010
    private static let scatter: CGFloat = 0.055

    func density(at point: CGPoint) -> CGFloat {
        var nearest = CGFloat.greatestFiniteMagnitude
        for bone in bones {
            nearest = min(nearest, bone.distance(to: point))
        }
        guard nearest > 0 else { return 1 }
        guard nearest < Self.scatter else { return 0 }
        let fade = 1 - nearest / Self.scatter
        return max(1 - nearest / Self.edge, fade * fade * 0.42)
    }

    // MARK: - Screen

    func draw(in ctx: GraphicsContext, size: CGSize, tint: Color) {
        let side = min(size.width, size.height)
        guard side > 12 else { return }

        let columns = min(40, max(28, Int(side / 6)))
        let span = side * 0.94
        let pitch = span / CGFloat(columns)
        let centre = CGPoint(x: size.width / 2, y: size.height / 2)
        let origin = CGPoint(x: centre.x - span / 2, y: centre.y - span / 2)
        let rings = Int(CGFloat(columns) * 0.74) + 2
        let tilt = cos(Self.screenAngle), rake = sin(Self.screenAngle)

        var ink = Path()
        for row in -rings...rings {
            for column in -rings...rings {
                let grit = Self.grit(column, row)
                let x = CGFloat(column) * pitch, y = CGFloat(row) * pitch
                let dot = CGPoint(
                    x: centre.x + x * tilt - y * rake + grit.drift.x * pitch * 0.3,
                    y: centre.y + x * rake + y * tilt + grit.drift.y * pitch * 0.3
                )
                let unit = CGPoint(x: (dot.x - origin.x) / span, y: (dot.y - origin.y) / span)
                guard unit.x > -0.1, unit.x < 1.1, unit.y > -0.1, unit.y < 1.1 else { continue }

                let solid = density(at: unit) * (1.30 - 0.60 * grit.erosion)
                guard solid > 0.14 else { continue }

                let radius = pitch * 0.46 * min(1, solid).squareRoot() * (0.86 + 0.26 * grit.scale)
                ink.addEllipse(
                    in: CGRect(
                        x: dot.x - radius, y: dot.y - radius,
                        width: radius * 2, height: radius * 2
                    )
                )
            }
        }
        ctx.fill(ink, with: .color(tint))
    }

    private static let screenAngle: CGFloat = 0.38

    private struct Grit {
        let drift: CGPoint
        let erosion: CGFloat
        let scale: CGFloat
    }

    private static func grit(_ column: Int, _ row: Int) -> Grit {
        var bits = UInt64(bitPattern: Int64(column)) &* 0x9E3779B97F4A7C15
        bits ^= UInt64(bitPattern: Int64(row)) &* 0xC2B2AE3D27D4EB4F
        bits ^= bits >> 29
        bits = bits &* 0xBF58476D1CE4E5B9
        bits ^= bits >> 32
        bits = bits &* 0x94D049BB133111EB
        bits ^= bits >> 31
        func slice(_ shift: UInt64) -> CGFloat {
            CGFloat(Double((bits >> shift) & 0xFFFF) / 65535)
        }
        return Grit(
            drift: CGPoint(x: slice(0) - 0.5, y: slice(16) - 0.5),
            erosion: slice(32),
            scale: slice(48)
        )
    }
}

// MARK: - Poses

extension HalftoneFigure {
    static func standing(reach: Double, sway: Double) -> HalftoneFigure {
        let rise = CGFloat(reach) * 0.016
        let lean = CGFloat(sway) * CGFloat(reach) * 0.022

        let head = CGPoint(x: 0.5 + lean * 1.3, y: 0.118 - rise)
        let shoulderSpan = lerp(0.100, 0.094, reach)
        let shoulderY = lerp(0.268, 0.252, reach)

        var bones = chain([
            Joint(at: CGPoint(x: 0.5 + lean * 1.1, y: 0.190 - rise), radius: 0.016),
            Joint(at: CGPoint(x: 0.5 + lean * 0.9, y: shoulderY), radius: 0.048),
            Joint(at: CGPoint(x: 0.5 + lean * 0.7, y: 0.326 - rise), radius: 0.066),
            Joint(at: CGPoint(x: 0.5 + lean * 0.4, y: 0.416 - rise * 0.8), radius: 0.048),
            Joint(at: CGPoint(x: 0.5 + lean * 0.2, y: 0.492 - rise * 0.5), radius: 0.062)
        ])
        bones.append(Bone(a: head, b: head, radius: 0.056))
        bones.append(
            Bone(
                a: CGPoint(x: 0.5 - shoulderSpan + lean, y: shoulderY),
                b: CGPoint(x: 0.5 + shoulderSpan + lean, y: shoulderY),
                radius: 0.024
            )
        )

        for side in [-1.0, 1.0] as [CGFloat] {
            bones += chain([
                Joint(
                    at: CGPoint(x: 0.5 + side * shoulderSpan + lean, y: shoulderY + 0.004),
                    radius: 0.027
                ),
                Joint(
                    at: CGPoint(
                        x: 0.5 + side * lerp(0.140, 0.176, reach) + lean * 1.1,
                        y: lerp(0.400, 0.208, reach) - rise
                    ),
                    radius: 0.022
                ),
                Joint(
                    at: CGPoint(
                        x: 0.5 + side * lerp(0.150, 0.133, reach) + lean * 1.3,
                        y: lerp(0.526, 0.072, reach) - rise
                    ),
                    radius: 0.018
                )
            ])

            bones += chain([
                Joint(at: CGPoint(x: 0.5 + side * 0.048, y: 0.500 - rise * 0.5), radius: 0.036),
                Joint(
                    at: CGPoint(x: 0.5 + side * lerp(0.064, 0.054, reach), y: 0.694 - rise * 0.3),
                    radius: 0.027
                ),
                Joint(
                    at: CGPoint(x: 0.5 + side * lerp(0.072, 0.060, reach), y: 0.858 - rise * 0.2),
                    radius: 0.020
                ),
                Joint(at: CGPoint(x: 0.5 + side * lerp(0.074, 0.062, reach), y: 0.894), radius: 0.018)
            ])
        }

        return HalftoneFigure(bones: bones)
    }

    static func seated(lift: Double) -> HalftoneFigure {
        let hip = CGPoint(x: lerp(0.312, 0.322, lift), y: lerp(0.610, 0.600, lift))
        let arch = CGPoint(x: lerp(0.380, 0.326, lift), y: lerp(0.480, 0.450, lift))
        let neck = CGPoint(x: lerp(0.480, 0.332, lift), y: lerp(0.372, 0.288, lift))
        let head = CGPoint(x: lerp(0.536, 0.338, lift), y: lerp(0.288, 0.196, lift))

        let spine: [CGFloat] = [0.058, 0.048, 0.044, 0.052, 0.016]
        var bones = chain(spine.enumerated().map { step, radius in
            Joint(
                at: curve(hip, arch, neck, CGFloat(step) / CGFloat(spine.count - 1)),
                radius: radius
            )
        })
        bones.append(Bone(a: head, b: head, radius: 0.058))

        bones += chain([
            Joint(at: CGPoint(x: lerp(0.468, 0.340, lift), y: lerp(0.416, 0.336, lift)), radius: 0.024),
            Joint(at: CGPoint(x: lerp(0.496, 0.372, lift), y: lerp(0.508, 0.470, lift)), radius: 0.020),
            Joint(at: CGPoint(x: lerp(0.604, 0.578, lift), y: lerp(0.556, 0.546, lift)), radius: 0.017)
        ])

        bones += chain([
            Joint(at: CGPoint(x: hip.x + 0.006, y: hip.y + 0.010), radius: 0.040),
            Joint(at: CGPoint(x: 0.620, y: 0.620), radius: 0.032),
            Joint(at: CGPoint(x: 0.660, y: 0.848), radius: 0.023),
            Joint(at: CGPoint(x: 0.744, y: 0.888), radius: 0.019)
        ])

        return HalftoneFigure(bones: bones)
    }

    private static func chain(_ joints: [Joint]) -> [Bone] {
        let facets = 3
        var bones = joints.map { Bone(a: $0.at, b: $0.at, radius: $0.radius) }
        for (start, end) in zip(joints, joints.dropFirst()) {
            for facet in 0..<facets {
                let from = CGFloat(facet) / CGFloat(facets)
                let to = CGFloat(facet + 1) / CGFloat(facets)
                bones.append(
                    Bone(
                        a: between(start.at, end.at, from),
                        b: between(start.at, end.at, to),
                        radius: start.radius
                            + (end.radius - start.radius) * (from + to) / 2
                    )
                )
            }
        }
        return bones
    }

    private static func between(_ a: CGPoint, _ b: CGPoint, _ t: CGFloat) -> CGPoint {
        CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t)
    }

    private static func curve(
        _ start: CGPoint, _ control: CGPoint, _ end: CGPoint, _ t: CGFloat
    ) -> CGPoint {
        let u = 1 - t
        return CGPoint(
            x: u * u * start.x + 2 * u * t * control.x + t * t * end.x,
            y: u * u * start.y + 2 * u * t * control.y + t * t * end.y
        )
    }

    private static func lerp(_ a: CGFloat, _ b: CGFloat, _ t: Double) -> CGFloat {
        a + (b - a) * CGFloat(t)
    }
}
