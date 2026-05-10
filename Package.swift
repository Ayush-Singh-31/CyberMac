// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "CyberMac",
    platforms: [
        .macOS(.v15)
    ],
    products: [
        .library(
            name: "CyberMacCore",
            targets: ["CyberMacCore"]
        ),
        .executable(
            name: "cybermac",
            targets: ["cybermac"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/weichsel/ZIPFoundation.git", from: "0.9.19")
    ],
    targets: [
        .target(
            name: "CyberMacCore",
            dependencies: [
                .product(name: "ZIPFoundation", package: "ZIPFoundation")
            ]
        ),
        .executableTarget(
            name: "cybermac",
            dependencies: ["CyberMacCore"]
        ),
        .testTarget(
            name: "CyberMacCoreTests",
            dependencies: [
                "CyberMacCore",
                .product(name: "ZIPFoundation", package: "ZIPFoundation")
            ]
        )
    ]
)
