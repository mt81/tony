// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "TonyStore",
    platforms: [
        .iOS("27.0"),
        .macOS("27.0"),
    ],
    products: [
        .library(name: "TonyStore", targets: ["TonyStore"]),
    ],
    dependencies: [
        .package(path: "../TonyCore"),
    ],
    targets: [
        .target(name: "TonyStore", dependencies: ["TonyCore"]),
        .testTarget(name: "TonyStoreTests", dependencies: ["TonyStore"]),
    ]
)
