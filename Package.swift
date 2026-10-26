// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "Nudge",
    platforms: [.macOS(.v13)],
    targets: [
        // Pure geometry: where a window should go. No AppKit, fully unit tested.
        .target(name: "NudgeCore"),
        // The background app: hotkeys + Accessibility API.
        .executableTarget(name: "Nudge", dependencies: ["NudgeCore"]),
        .testTarget(name: "NudgeCoreTests", dependencies: ["NudgeCore"]),
    ]
)
