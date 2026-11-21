// swift-tools-version: 6.2
import PackageDescription
import Foundation

// Explicit offline development mode. Distribution builds always include Sparkle.
let updatesEnabled = ProcessInfo.processInfo.environment["SMARTNOTCH_NO_UPDATER"] != "1"

let package = Package(
    name: "SmartNotch",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "SmartNotch", targets: ["SmartNotch"])],
    dependencies: updatesEnabled ? [
        .package(url: "https://github.com/sparkle-project/Sparkle", exact: "2.10.1")
    ] : [],
    targets: [
        .executableTarget(name: "SmartNotch", dependencies: updatesEnabled ? [
            .product(name: "Sparkle", package: "Sparkle")
        ] : [], swiftSettings: [
            .defaultIsolation(MainActor.self),
            .enableUpcomingFeature("NonisolatedNonsendingByDefault")
        ], linkerSettings: updatesEnabled ? [
            .unsafeFlags(["-Xlinker", "-rpath", "-Xlinker", "@executable_path/../Frameworks"])
        ] : []),
        .testTarget(name: "SmartNotchTests", dependencies: ["SmartNotch"])
    ]
)
