// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "GabGab",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "GabGab",
            targets: ["GabGab"]
        ),
        .executable(
            name: "gabgab-cli",
            targets: ["GabGabCLI"]
        ),
        .executable(
            name: "gabgab-mcp",
            targets: ["GabGabMCP"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.0.0"),
    ],
    targets: [
        .target(
            name: "GabGab",
            dependencies: []
        ),
        .executableTarget(
            name: "GabGabCLI",
            dependencies: [
                "GabGab",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ]
        ),
        .executableTarget(
            name: "GabGabMCP",
            dependencies: [
                "GabGab"
            ]
        ),
        .testTarget(
            name: "GabGabTests",
            dependencies: ["GabGab"]
        ),
    ]
)
