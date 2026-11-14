// swift-tools-version: 6.0
import PackageDescription

// The UI, on its own: it knows nothing of the business model or of the reducers.
let package = Package(
    name: "TonyUIKit",
    platforms: [
        .iOS("27.0"),
        .macOS("27.0"),
    ],
    products: [
        .library(name: "TonyUIModels", targets: ["TonyUIModels"]),
        .library(name: "TonyUIKit", targets: ["TonyUIKit"]),
    ],
    targets: [
        // What each view shows and calls, in plain Swift. Reducers build these.
        .target(name: "TonyUIModels"),
        // The SwiftUI views that draw the data models, with Tony's colours, fonts and artwork.
        .target(
            name: "TonyUIKit",
            dependencies: ["TonyUIModels"],
            resources: [.process("Resources")]
        ),
    ]
)
