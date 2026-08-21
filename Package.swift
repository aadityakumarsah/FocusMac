// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "MacFocusOS",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "MacFocusOS", targets: ["MacFocusOS"])
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
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(
            name: "MacFocusOSCoreTests",
            dependencies: ["MacFocusOSCore"],
            path: "Tests/MacFocusOSCoreTests"
        )
    ]
)
