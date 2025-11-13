// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "MacTools",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        // The main executable CLI tool
        .executable(
            name: "mactools",
            targets: ["MacToolsCLI"]
        ),
        // Library for embedding in other applications
        .library(
            name: "MacToolsCore",
            targets: ["MacToolsCore"]
        ),
    ],
    dependencies: [
        // Add Swift Argument Parser for CLI
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.3.0"),
        // Add Swift Log for logging
        .package(url: "https://github.com/apple/swift-log", from: "1.5.0"),
    ],
    targets: [
        // Core library with daemon infrastructure
        .target(
            name: "MacToolsCore",
            dependencies: [
                .product(name: "Logging", package: "swift-log"),
            ],
            path: "Sources/MacToolsCore"
        ),

        // Key manipulation module
        .target(
            name: "KeyManipulation",
            dependencies: ["MacToolsCore"],
            path: "Sources/KeyManipulation"
        ),

        // Window manipulation module
        .target(
            name: "WindowManipulation",
            dependencies: ["MacToolsCore"],
            path: "Sources/WindowManipulation"
        ),

        // Caps Lock manipulation module
        .target(
            name: "CapsLockAgent",
            dependencies: ["MacToolsCore"],
            path: "Sources/CapsLockAgent"
        ),

        // CLI executable
        .executableTarget(
            name: "MacToolsCLI",
            dependencies: [
                "MacToolsCore",
                "KeyManipulation",
                "WindowManipulation",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ],
            path: "Sources/MacToolsCLI"
        ),

        // Tests
        .testTarget(
            name: "MacToolsCoreTests",
            dependencies: ["MacToolsCore"],
            path: "Tests/MacToolsCoreTests"
        ),
        .testTarget(
            name: "KeyManipulationTests",
            dependencies: ["KeyManipulation", "MacToolsCore"],
            path: "Tests/KeyManipulationTests"
        ),
        .testTarget(
            name: "WindowManipulationTests",
            dependencies: ["WindowManipulation", "MacToolsCore"],
            path: "Tests/WindowManipulationTests"
        ),
        .testTarget(
            name: "CapsLockAgentTests",
            dependencies: ["CapsLockAgent", "MacToolsCore"],
            path: "Tests/CapsLockAgentTests"
        ),
    ]
)
