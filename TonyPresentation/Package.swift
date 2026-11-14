// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "TonyPresentation",
    defaultLocalization: "en",
    platforms: [
        .iOS("27.0"),
        .macOS("27.0"),
    ],
    products: [
        .library(name: "TonyPresentation", targets: ["TonyPresentation"]),
    ],
    dependencies: [
        .package(path: "../TonyCore"),
        .package(path: "../TonyUIKit"),
    ],
    targets: [
        .target(
            name: "TonyPresentation",
            dependencies: ["TonyCore", "TonyUIKit"],
            resources: [.process("Resources")]
        ),
        .testTarget(name: "TonyPresentationTests", dependencies: ["TonyPresentation"]),
    ]
)
