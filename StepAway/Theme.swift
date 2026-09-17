import AppKit
import SwiftUI

enum Theme {
    enum Palette {
        static let ink      = Color(.sRGB, red: 0.929, green: 0.902, blue: 0.855)
        static let chalk    = ink.opacity(0.86)
        static let inkMuted = ink.opacity(0.52)
        static let hairline = ink.opacity(0.26)
        static let border   = ink.opacity(0.09)
        static let surface  = Color.white.opacity(0.04)
        static let ember    = Color(.sRGB, red: 0.769, green: 0.071, blue: 0.031)
        static let depth    = Color(.sRGB, red: 0.000, green: 0.235, blue: 0.322)
        static let flame    = Color(.sRGB, red: 0.910, green: 0.376, blue: 0.122)
        static let lagoon   = Color(.sRGB, red: 0.231, green: 0.545, blue: 0.639)
    }

    static let signature = LinearGradient(
        colors: [Palette.flame, Palette.lagoon],
        startPoint: UnitPoint(x: 0, y: 0.46),
        endPoint: UnitPoint(x: 1, y: 0.54)
    )

    enum Radius {
        static let pill: CGFloat = 999
        static let lg: CGFloat = 24
        static let xl: CGFloat = 36
    }

    enum Motion {
        static let bloom  = Animation.smooth(duration: 0.85)
        static let settle = Animation.smooth(duration: 0.55, extraBounce: 0.12)
        static let quick  = Animation.snappy(duration: 0.26, extraBounce: 0.04)
        static let breathe = Animation.easeInOut(duration: 4).repeatForever(autoreverses: true)
    }

    // MARK: - Type

    enum Cut {
        case bold, heavy, black

        var face: String {
            switch self {
            case .bold:  "BarlowCondensed-Bold"
            case .heavy: "BarlowCondensed-ExtraBold"
            case .black: "BarlowCondensed-Black"
            }
        }
    }

    static func display(_ size: CGFloat, _ cut: Cut = .black) -> Font {
        .custom(cut.face, size: size)
    }

    static func voice(_ size: CGFloat, italic: Bool = true) -> Font {
        .custom(italic ? "CrimsonPro-LightItalic" : "CrimsonPro-Light", size: size)
    }

    static func label(_ size: CGFloat, emphasis: Bool = false) -> Font {
        .custom(emphasis ? "IBMPlexMono-Medium" : "IBMPlexMono-Regular", size: size)
    }

    static func counter(_ size: CGFloat) -> Font {
        .custom("IBMPlexMono-Regular", size: size)
    }

    static func registerBundledFonts() {
        let bundle = Bundle.main
        let urls = (bundle.urls(forResourcesWithExtension: "ttf", subdirectory: "Fonts") ?? [])
            + (bundle.urls(forResourcesWithExtension: "ttf", subdirectory: nil) ?? [])
        guard !urls.isEmpty else { return }
        CTFontManagerRegisterFontURLs(Array(Set(urls)) as CFArray, .process, true, nil)
    }
}

extension View {
    func microLabel(_ size: CGFloat = 10, tracking: CGFloat = 0.14, emphasis: Bool = false) -> some View {
        font(Theme.label(size, emphasis: emphasis))
            .tracking(size * tracking)
            .textCase(.uppercase)
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

struct DesktopBlur: NSViewRepresentable {
    var material: NSVisualEffectView.Material = .hudWindow
    var alpha: CGFloat = 1

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.blendingMode = .behindWindow
        view.state = .active
        view.appearance = NSAppearance(named: .darkAqua)
        view.material = material
        view.alphaValue = alpha
        return view
    }

    func updateNSView(_ view: NSVisualEffectView, context: Context) {
        view.material = material
        view.alphaValue = alpha
    }
}

struct ClearWindowBackground: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async { Self.clear(view.window) }
        return view
    }

    func updateNSView(_ view: NSView, context: Context) {}

    private static func clear(_ window: NSWindow?) {
        guard let window, window.isOpaque || window.backgroundColor != .clear else { return }
        window.isOpaque = false
        window.backgroundColor = .clear
    }
}

private struct GlassPanel<S: InsettableShape>: ViewModifier {
    let shape: S
    let material: NSVisualEffectView.Material

    func body(content: Content) -> some View {
        content
            .background {
                ZStack {
                    DesktopBlur(material: material)
                    Theme.Palette.surface
                    AmberBloom(intensity: 0.75, animated: false)
                    FilmGrain(intensity: 0.09)
                }
                .clipShape(shape)
            }
            .overlay { sheen }
            .overlay { rim }
            .overlay { crown }
            .shadow(color: .black.opacity(0.60), radius: 20, y: 8)
    }

    private var sheen: some View {
        shape
            .fill(
                LinearGradient(
                    colors: [Color.white.opacity(0.10), Color.white.opacity(0.02), .clear],
                    startPoint: .top, endPoint: UnitPoint(x: 0.5, y: 0.62)
                )
            )
            .allowsHitTesting(false)
    }

    private var rim: some View {
        shape
            .strokeBorder(
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.30),
                        Theme.Palette.border,
                        Color.white.opacity(0.04)
                    ],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ),
                lineWidth: 1
            )
            .allowsHitTesting(false)
    }

    private var crown: some View {
        shape
            .strokeBorder(
                LinearGradient(
                    colors: [Color.white.opacity(0.46), .clear],
                    startPoint: .top, endPoint: UnitPoint(x: 0.5, y: 0.28)
                ),
                lineWidth: 1.2
            )
            .blur(radius: 1)
            .allowsHitTesting(false)
    }
}

extension View {
    func glassPanel(
        cornerRadius: CGFloat = Theme.Radius.xl,
        material: NSVisualEffectView.Material = .hudWindow
    ) -> some View {
        modifier(
            GlassPanel(
                shape: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous),
                material: material
            )
        )
    }

    func glassPill(prominent: Bool = false) -> some View {
        glassEffect(prominent ? .regular.interactive() : .clear.interactive(), in: .capsule)
            .overlay {
                Capsule()
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(prominent ? 0.36 : 0.18),
                                Color.white.opacity(0.05)
                            ],
                            startPoint: .top, endPoint: .bottom
                        ),
                        lineWidth: 1
                    )
                    .allowsHitTesting(false)
            }
    }
}

// MARK: - Signature marks

struct SectionLabel: View {
    private let text: String

    init(_ text: String) { self.text = text }

    var body: some View {
        HStack(spacing: 10) {
            Rectangle()
                .fill(Theme.signature)
                .frame(width: 20, height: 1)
            Text(text)
                .microLabel(9, tracking: 0.26)
                .foregroundStyle(Theme.signature)
            Spacer(minLength: 0)
        }
    }
}

struct Brandmark: View {
    var body: some View {
        Link(destination: URL(string: "https://robinhrdlicka.cz")!) {
            HStack(spacing: 5) {
                Text("Made by")
                    .foregroundStyle(Theme.Palette.ink.opacity(0.28))
                Text("HROB")
                    .foregroundStyle(Theme.Palette.ember)
            }
            .microLabel(9, tracking: 0.22, emphasis: true)
        }
        .buttonStyle(.plain)
        .pointerStyle(.link)
    }
}
