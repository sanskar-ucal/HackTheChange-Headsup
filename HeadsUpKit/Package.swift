// swift-tools-version: 5.10
import PackageDescription

let strictConcurrency: [SwiftSetting] = [.enableExperimentalFeature("StrictConcurrency")]

let package = Package(
    name: "HeadsUpKit",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "HeadsUpKit", targets: ["HeadsUpKit"]),
    ],
    targets: [
        .target(
            name: "HeadsUpKit",
            path: "Sources",
            swiftSettings: strictConcurrency
        ),
        .testTarget(
            name: "HeadsUpKitTests",
            dependencies: ["HeadsUpKit"],
            path: "Tests/HeadsUpKitTests",
            resources: [.copy("Fixtures")],
            swiftSettings: strictConcurrency
        ),
    ]
)
