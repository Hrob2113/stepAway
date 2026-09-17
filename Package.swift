// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "StepAway",
    platforms: [.macOS("26.2")],
    targets: [
        .target(
            name: "StepAwayCore",
            path: "StepAway",
            exclude: ["StepAwayApp.swift", "Assets.xcassets", "Fonts"],
            swiftSettings: [.swiftLanguageMode(.v6), .defaultIsolation(MainActor.self)]
        ),
        .testTarget(
            name: "StepAwayCoreTests",
            dependencies: ["StepAwayCore"],
            path: "Tests/StepAwayCoreTests",
            swiftSettings: [.swiftLanguageMode(.v6), .defaultIsolation(MainActor.self)]
        )
    ]
)
