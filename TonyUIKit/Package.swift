// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "TonyUIKit",
    platforms: [
        .iOS("27.0"),
        .macOS("27.0"),
    ],
    products: [
        .library(name: "TonyUIKit", targets: ["TonyUIKit"]),
    ],
    targets: [
        .target(name: "TonyUIKit"),
    ]
)
