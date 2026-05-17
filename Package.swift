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
        ),
        .executable(
            name: "CyberMacApp",
            targets: ["CyberMacApp"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/weichsel/ZIPFoundation.git", from: "0.9.19")
    ],
    targets: [
        .target(
            name: "CyberMacBC7Decoder",
            path: "Sources/CyberMacBC7Decoder",
            publicHeadersPath: "include",
            cSettings: [
                .headerSearchPath("include")
            ]
        ),
        .target(
            name: "CyberMacCore",
            dependencies: [
                .product(name: "ZIPFoundation", package: "ZIPFoundation"),
                "CyberMacBC7Decoder"
            ],
            linkerSettings: [
                .linkedLibrary("sqlite3")
            ]
        ),
        .executableTarget(
            name: "cybermac",
            dependencies: ["CyberMacCore"]
        ),
        .executableTarget(
            name: "CyberMacApp",
            dependencies: ["CyberMacCore"],
            path: "CyberMacApp",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "CyberMacCoreTests",
            dependencies: [
                "CyberMacCore",
                .product(name: "ZIPFoundation", package: "ZIPFoundation")
            ]
        ),
        .testTarget(
            name: "CyberMacAppTests",
            dependencies: [
                "CyberMacApp",
                "CyberMacCore"
            ]
        )
    ]
)
