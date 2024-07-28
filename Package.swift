// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "ForkedResource",
    platforms: [.macOS(.v10_15), .iOS(.v13), .tvOS(.v13), .watchOS(.v6), .macCatalyst(.v13)],
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
