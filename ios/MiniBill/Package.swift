// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "MiniBillCore",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "MiniBillCore", targets: ["MiniBillCore"]),
        .library(name: "MiniBillData", targets: ["MiniBillData"]),
    ],
    targets: [
        .target(
            name: "MiniBillCore",
            path: "MiniBill/Core"
        ),
        .target(
            name: "MiniBillData",
            dependencies: ["MiniBillCore"],
            path: "MiniBill/Data"
        ),
        .testTarget(
            name: "MiniBillCoreTests",
            dependencies: ["MiniBillCore", "MiniBillData"],
            path: "Tests/MiniBillCoreTests"
        ),
    ]
)
