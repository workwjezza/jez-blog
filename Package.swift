// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "jez-blog",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "jez-blog",
            targets: ["jez-blog"]
        )
    ],
    targets: [
        .executableTarget(
            name: "jez-blog",
            dependencies: [],
            resources: [
                .process("Assets.xcassets")
            ]
        )
    ]
)
