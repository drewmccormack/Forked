// swift-tools-version: 6.0

import PackageDescription
import CompilerPluginSupport

let package = Package(
    name: "Forked",
    platforms: [.macOS(.v15), .iOS(.v18), .tvOS(.v18), .watchOS(.v10), .macCatalyst(.v18)],
    products: [
        .library(
            name: "Forked",
            targets: ["Forked"]),
        .library(
            name: "ForkedMerge",
            targets: ["ForkedMerge"]),
        .library(
            name: "ForkedModel",
            targets: ["ForkedModel"]),
        .library(
            name: "ForkedCloudKit",
            targets: ["ForkedCloudKit"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-docc-plugin", from: "1.0.0"),
        .package(url: "https://github.com/apple/swift-async-algorithms", from: "1.0.2"),
        .package(url: "https://github.com/apple/swift-syntax.git", from: "509.0.0"),
    ],
    targets: [
        .macro(
            name: "ForkedModelMacros",
            dependencies: [
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
            ]
        ),
        .target(
            name: "Forked"),
        .target(
            name: "ForkedMerge",
            dependencies: [
                "Forked",
            ]
        ),
        .target(
            name: "ForkedModel",
            dependencies: [
                "Forked",
                "ForkedMerge",
                "ForkedModelMacros",
            ]
        ),
        .target(
            name: "ForkedCloudKit",
            dependencies: [
                "Forked",
                .product(name: "AsyncAlgorithms", package: "swift-async-algorithms"),
            ]
        ),
        .testTarget(
            name: "ForkedTests",
            dependencies: [
                "Forked",
                "ForkedModelMacros",
                "ForkedMerge",
                .product(name: "SwiftSyntaxMacrosTestSupport", package: "swift-syntax"),
            ]
        ),
    ],
    swiftLanguageModes: [.v6]
)
