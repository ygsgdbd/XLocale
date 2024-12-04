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
        base: [
            "SWIFT_EMIT_LOC_STRINGS": "YES",
            "DEVELOPMENT_LANGUAGE": "zh-Hans"
        ],
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
            infoPlist: .extendingDefault(with: [
                "CFBundleDevelopmentRegion": "zh-Hans",
                "CFBundleLocalizations": ["zh-Hans", "en"],
                "NSHumanReadableCopyright": "Copyright © 2024 linhey. All rights reserved."
            ]),
            sources: ["XLocale/**"],
            resources: [
                "XLocale/Resources/**"
            ],
            dependencies: [
                .package(product: "SwiftUIX"),
                .package(product: "OpenAI"),
                .package(product: "SwifterSwift")
            ],
            settings: .settings(
                base: [
                    "SWIFT_EMIT_LOC_STRINGS": "YES",
                    "DEVELOPMENT_LANGUAGE": "zh-Hans"
                ]
            )
        )
    ],
    resourceSynthesizers: [
        .strings()
    ]
)
