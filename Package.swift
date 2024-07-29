// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "ForkedResource",
    platforms: [.macOS(.v12), .iOS(.v14), .tvOS(.v14), .watchOS(.v7), .macCatalyst(.v14)],
    products: [
        .library(
            name: "ForkedResource",
            targets: ["ForkedResource"]),
    ],
    targets: [
        .target(
            name: "ForkedResource"),
        .testTarget(
            name: "ForkedResourceTests",
            dependencies: ["ForkedResource"]
        ),
    ]
)
