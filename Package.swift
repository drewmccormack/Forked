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
            name: "ForkedCloudKit",
            targets: ["ForkedCloudKit"]),
        .library(
            name: "ForkedModel",
            targets: ["ForkedModel"]),
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
            name: "ForkedCloudKit",
            dependencies: [
                "Forked",
                .product(name: "AsyncAlgorithms", package: "swift-async-algorithms"),
            ]
        ),
        .target(
            name: "ForkedModel",
            dependencies: [
                "Forked",
                "ForkedModelMacros",
            ]
        ),
        .testTarget(
            name: "ForkedTests",
            dependencies: [
                "Forked",
                "ForkedModelMacros",
                .product(name: "SwiftSyntaxMacrosTestSupport", package: "swift-syntax"),
            ]
        ),
    ],
    swiftLanguageModes: [.v6]
)
