// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "Forked",
    platforms: [.macOS(.v12), .iOS(.v14), .tvOS(.v14), .watchOS(.v7), .macCatalyst(.v14)],
    products: [
        .library(
            name: "Forked",
            targets: ["Forked"]),
    ],
    targets: [
        .target(
            name: "Forked"),
        .testTarget(
            name: "ForkedTests",
            dependencies: ["Forked"]
        ),
    ],
    swiftLanguageVersions: [.v6]
)
