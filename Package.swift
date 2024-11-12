// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "Forked",
    platforms: [.macOS(.v15), .iOS(.v18), .tvOS(.v18), .watchOS(.v10), .macCatalyst(.v18)],
    products: [
        .library(
            name: "Forked",
            targets: ["Forked"]),
        .library(
            name: "ForkedCloudKit",
            targets: ["ForkedCloudKit"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-docc-plugin", from: "1.0.0"),
        .package(url: "https://github.com/apple/swift-async-algorithms", from: "1.0.2"),
    ],
    targets: [
        .target(
            name: "Forked"),
        .target(
            name: "ForkedCloudKit",
            dependencies: [
                "Forked",
                .product(name: "AsyncAlgorithms", package: "swift-async-algorithms"),
            ]
        ),
        .testTarget(
            name: "ForkedTests",
            dependencies: ["Forked"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
