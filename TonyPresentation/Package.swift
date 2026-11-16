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
        .library(name: "TonyScreens", targets: ["TonyScreens"]),
    ],
    dependencies: [
        .package(path: "../TonyCore"),
        .package(path: "../TonyUIKit"),
    ],
    targets: [
        .target(
            name: "TonyPresentation",
            dependencies: ["TonyCore", .product(name: "TonyUIModels", package: "TonyUIKit")],
            resources: [.process("Resources")]
        ),
        // The screens: SwiftUI views that draw the screens' data models with the components of TonyUIKit.
        .target(
            name: "TonyScreens",
            dependencies: [
                "TonyPresentation",
                .product(name: "TonyUIModels", package: "TonyUIKit"),
                .product(name: "TonyUIKit", package: "TonyUIKit"),
            ]
        ),
        .testTarget(name: "TonyPresentationTests", dependencies: ["TonyPresentation"]),
    ]
)
