// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "CraftSide",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "CraftSide", targets: ["CraftSide"])
    ],
    targets: [
        .executableTarget(
            name: "CraftSide",
            path: "Sources/CraftSide"
        )
    ]
)
