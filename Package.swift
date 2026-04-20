// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "RoughSwiftUI",
    platforms: [
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "RoughSwiftUI",
            targets: ["RoughSwiftUI"]
        ),
        // Optional Metal-accelerated renderer. Importing this product is opt-in:
        // it adds a Metal/MetalKit dependency and provides `MetalRoughRenderer`
        // and the `RoughView.metalAccelerated()` modifier. The base
        // `RoughSwiftUI` library does not link against Metal.
        .library(
            name: "RoughSwiftUIMetal",
            targets: ["RoughSwiftUIMetal"]
        ),
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        // .package(url: /* package url */, from: "1.0.0"),
    ],
    targets: [
        .target(
            name: "RoughSwiftUI"
        ),
        .target(
            name: "RoughSwiftUIMetal",
            dependencies: ["RoughSwiftUI"],
            resources: [
                .process("Shaders")
            ]
        ),
        .testTarget(
            name: "RoughSwiftUITests",
            dependencies: ["RoughSwiftUI"]
        ),
        .testTarget(
            name: "RoughSwiftUIMetalTests",
            dependencies: ["RoughSwiftUIMetal"]
        ),
    ]
)
