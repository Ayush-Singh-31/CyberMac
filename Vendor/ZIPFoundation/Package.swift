// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ZIPFoundation",
    platforms: [.macOS(.v15)],
    products: [.library(name: "ZIPFoundation", targets: ["ZIPFoundation"])],
    targets: [.target(name: "ZIPFoundation", resources: [.copy("Resources/PrivacyInfo.xcprivacy")])],
    swiftLanguageModes: [.v5]
)
