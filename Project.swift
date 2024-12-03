import ProjectDescription

let project = Project(
    name: "XLocale",
    organizationName: "com.linhey",
    packages: [
        .remote(url: "https://github.com/SwiftUIX/SwiftUIX.git", requirement: .upToNextMajor(from: "0.2.3")),
        .remote(url: "https://github.com/MacPaw/OpenAI.git", requirement: .upToNextMajor(from: "0.3.0")),
        .remote(url: "https://github.com/SwifterSwift/SwifterSwift.git", requirement: .upToNextMajor(from: "6.0.0"))
    ],
    settings: .settings(
        base: [:],
        configurations: [
            .debug(name: "Debug"),
            .release(name: "Release")
        ]
    ),
    targets: [
        .target(
            name: "XLocale",
            destinations: [.mac],
            product: .app,
            bundleId: "com.linhey.XLocale",
            deploymentTargets: .macOS("13.0"),
            infoPlist: .default,
            sources: ["XLocale/**"],
            dependencies: [
                .package(product: "SwiftUIX"),
                .package(product: "OpenAI"),
                .package(product: "SwifterSwift")
            ]
        )
    ]
)
