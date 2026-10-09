// swift-tools-version: 6.0
import PackageDescription
import Foundation

// The test target is wired in only when the Tests directory is present. Tests
// aren't part of the published sources, so a fresh clone builds without them;
// drop the Tests/IndexCoreTests folder back in and `swift test` picks it up.
var targets: [Target] = [
    .target(name: "IndexCore"),
    // The SwiftUI app is normally built by Xcode from App/project.yml. It is
    // also wired here as an executable target so the app can be built with
    // `swift build` alone (scripts/build-mac.sh), which is how the Intel
    // (x86_64) build is produced.
    .executableTarget(
        name: "EverythingMac",
        dependencies: ["IndexCore"],
        path: "App/Sources",
        // The app calls AppKit APIs (NSSavePanel, NSMenu, …) that became
        // @MainActor-annotated in the macOS 15 SDK. Those call sites are plain
        // nonisolated statics, so Swift 6 language mode rejects them unless the
        // whole module defaults to the main actor (a Swift 6.2 / Xcode 26
        // setting). Until this toolchain is upgraded, build the app in Swift 5
        // language mode: same code, same behavior, no source changes.
        swiftSettings: [.swiftLanguageMode(.v5)]
    ),
]
if FileManager.default.fileExists(atPath: "Tests/IndexCoreTests") {
    targets.append(.testTarget(name: "IndexCoreTests", dependencies: ["IndexCore"]))
}

let package = Package(
    name: "IndexCore",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "IndexCore", targets: ["IndexCore"]),
    ],
    targets: targets
)
