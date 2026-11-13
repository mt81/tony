import ProjectDescription

let deploymentTargets: DeploymentTargets = .iOS("27.0")
let destinations: Destinations = [.iPhone, .iPad]
let appGroupEntitlements: Entitlements = .dictionary([
    "com.apple.security.application-groups": ["group.com.mt81.tony"],
])

let project = Project(
    name: "Tony",
    packages: [
        .package(path: "TonyCore"),
        .package(path: "TonyStore"),
    ],
    settings: .settings(base: [
        "SWIFT_VERSION": "6.0",
        "MARKETING_VERSION": "0.1.0",
        "CURRENT_PROJECT_VERSION": "1",
    ]),
    targets: [
        .target(
            name: "TonyApp",
            destinations: destinations,
            product: .app,
            productName: "Tony",
            bundleId: "com.mt81.tony",
            deploymentTargets: deploymentTargets,
            infoPlist: .extendingDefault(with: [
                "CFBundleDisplayName": "Tony",
                "UILaunchScreen": [:],
                "UIUserInterfaceStyle": "Dark",
                "UISupportedInterfaceOrientations": [
                    "UIInterfaceOrientationPortrait",
                ],
                "UISupportedInterfaceOrientations~ipad": [
                    "UIInterfaceOrientationPortrait",
                    "UIInterfaceOrientationPortraitUpsideDown",
                    "UIInterfaceOrientationLandscapeLeft",
                    "UIInterfaceOrientationLandscapeRight",
                ],
            ]),
            buildableFolders: ["TonyApp"],
            entitlements: appGroupEntitlements,
            dependencies: [
                .package(product: "TonyCore"),
                .package(product: "TonyStore"),
                .target(name: "TonyDesign"),
                .target(name: "TonyWidgets"),
            ]
        ),
        .target(
            name: "TonyDesign",
            destinations: destinations,
            product: .framework,
            bundleId: "com.mt81.tony.design",
            deploymentTargets: deploymentTargets,
            buildableFolders: ["TonyDesign"]
        ),
        .target(
            name: "TonyWidgets",
            destinations: destinations,
            product: .appExtension,
            bundleId: "com.mt81.tony.widgets",
            deploymentTargets: deploymentTargets,
            infoPlist: .extendingDefault(with: [
                "CFBundleDisplayName": "Tony",
                "NSExtension": [
                    "NSExtensionPointIdentifier": "com.apple.widgetkit-extension",
                ],
            ]),
            buildableFolders: ["TonyWidgets"],
            entitlements: appGroupEntitlements,
            dependencies: [
                .package(product: "TonyCore"),
                .package(product: "TonyStore"),
            ]
        ),
    ]
)
