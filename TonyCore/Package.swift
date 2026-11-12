// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "TonyCore",
    platforms: [
        .iOS("27.0"),
        .macOS("27.0"),
    ],
    products: [
        .library(name: "TonyCore", targets: ["TonyCore"]),
    ],
    targets: [
        .target(name: "TonyCore"),
        .testTarget(name: "TonyCoreTests", dependencies: ["TonyCore"]),
    ]
)
