// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "MacFocusOS",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "MacFocusOS", targets: ["MacFocusOS"]),
        .executable(name: "MacFocusOSCoreTests", targets: ["MacFocusOSCoreTests"])
    ],
    targets: [
        .target(
            name: "MacFocusOSCore",
            path: "Sources/MacFocusOSCore",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .executableTarget(
            name: "MacFocusOS",
            dependencies: ["MacFocusOSCore"],
            path: "Sources/MacFocusOS",
            resources: [.copy("Resources")],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .executableTarget(
            name: "MacFocusOSCoreTests",
            dependencies: ["MacFocusOSCore"],
            path: "Tests/MacFocusOSCoreTests",
            swiftSettings: [.swiftLanguageMode(.v5)]
        )
    ]
)
