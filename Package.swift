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
    dependencies: [
        .package(url: "https://github.com/apple/swift-docc-plugin", from: "1.0.0"),
    ],
    targets: [
        .target(
            name: "Forked"),
        .testTarget(
            name: "ForkedTests",
            dependencies: ["Forked"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
