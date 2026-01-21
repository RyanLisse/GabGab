// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "MLXVoice",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "MLXVoice",
            targets: ["MLXVoice"]
        ),
        .executable(
            name: "mlx-voice-cli",
            targets: ["mlx-voice-cli"]
        ),
        .executable(
            name: "mlx-voice-mcp-server",
            targets: ["mlx-voice-mcp-server"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.0.0"),
    ],
    targets: [
        .target(
            name: "MLXVoice",
            dependencies: []
        ),
        .executableTarget(
            name: "mlx-voice-cli",
            dependencies: [
                "MLXVoice",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ]
        ),
        .executableTarget(
            name: "mlx-voice-mcp-server",
            dependencies: [
                "MLXVoice"
            ]
        ),
        .testTarget(
            name: "MLXVoiceTests",
            dependencies: ["MLXVoice"]
        ),
    ]
)
