// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "out_of_memory_plugin",
    platforms: [
        .iOS("15.0")
    ],
    products: [
        .library(name: "out-of-memory-plugin", targets: ["out_of_memory_plugin"])
    ],
    dependencies: [
        .package(name: "FlutterFramework", path: "../FlutterFramework")
    ],
    targets: [
        .target(
            name: "out_of_memory_plugin",
            dependencies: [
                .product(name: "FlutterFramework", package: "FlutterFramework")
            ],
            resources: [
                // The plugin does not use any required-reason APIs and collects no data,
                // but ships an (empty) privacy manifest so App Store privacy reports are complete.
                .process("PrivacyInfo.xcprivacy")
            ]
        )
    ]
)
