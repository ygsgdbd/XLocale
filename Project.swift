import ProjectDescription

let project = Project(
    name: "XLocale",
    organizationName: "linhey",
    packages: [
        .remote(url: "https://github.com/sindresorhus/Defaults", requirement: .upToNextMajor(from: "7.3.1")),
        .remote(url: "https://github.com/SwiftUIX/SwiftUIX.git", requirement: .upToNextMajor(from: "0.2.3")),
        .remote(url: "https://github.com/SwifterSwift/SwifterSwift.git", requirement: .upToNextMajor(from: "6.0.0")),
        .remote(url: "https://github.com/MacPaw/OpenAI.git", requirement: .upToNextMajor(from: "0.3.0"))
    ],
    settings: .settings(
        base: [
            "MACOSX_DEPLOYMENT_TARGET": "13.0",
            "GENERATE_INFOPLIST_FILE": "YES",
            "CURRENT_PROJECT_VERSION": "1",
            "MARKETING_VERSION": "1.0.0",
            "INFOPLIST_KEY_CFBundleDisplayName": "XLocale",
            "INFOPLIST_KEY_NSHumanReadableCopyright": "Copyright © 2024 linhey. All rights reserved.",
            "INFOPLIST_KEY_CFBundleDevelopmentRegion": "zh-Hans",
            "INFOPLIST_KEY_CFBundleLocalizations": [
                "zh-Hans",
                "zh-Hant",
                "en",
                "ja"
            ],
            "SWIFT_EMIT_LOC_STRINGS": "YES",
            "USE_COMPILER_TO_EXTRACT_SWIFT_STRINGS": "YES",
            "LOCALIZATION_PREFERS_STRING_CATALOGS": "YES",
        ]
    ),
    targets: [
        // Main App
        .target(
            name: "XLocale",
            destinations: [.mac],
            product: .app,
            bundleId: "com.linhey.xlocale",
            deploymentTargets: .macOS("13.0"),
            infoPlist: .extendingDefault(with: [
                "CFBundleDocumentTypes": [
                    [
                        "CFBundleTypeName": "Xcode Project",
                        "CFBundleTypeRole": "Viewer",
                        "LSHandlerRank": "Default",
                        "LSItemContentTypes": ["com.apple.xcode.project"],
                        "LSTypeIsPackage": true,
                        "NSDocumentClass": "$(PRODUCT_MODULE_NAME).XcodeProject"
                    ],
                    [
                        "CFBundleTypeName": "Xcode Workspace",
                        "CFBundleTypeRole": "Viewer",
                        "LSHandlerRank": "Default",
                        "LSItemContentTypes": ["com.apple.xcode.workspace"],
                        "NSDocumentClass": "$(PRODUCT_MODULE_NAME).XcodeWorkspace"
                    ]
                ],
                "UTImportedTypeDeclarations": [
                    [
                        "UTTypeIdentifier": "com.apple.xcode.project",
                        "UTTypeDescription": "Xcode Project",
                        "UTTypeConformsTo": ["com.apple.package"],
                        "UTTypeTagSpecification": [
                            "public.filename-extension": ["xcodeproj"]
                        ]
                    ],
                    [
                        "UTTypeIdentifier": "com.apple.xcode.workspace",
                        "UTTypeDescription": "Xcode Workspace",
                        "UTTypeConformsTo": ["public.data", "public.directory"],
                        "UTTypeTagSpecification": [
                            "public.filename-extension": ["xcworkspace"]
                        ]
                    ]
                ]
            ]),
            sources: ["XLocale/**"],
            resources: [
                "XLocale/Resources/**",
                .folderReference(path: "XLocale/Resources/Localizations/zh-Hans.lproj"),
                .folderReference(path: "XLocale/Resources/Localizations/zh-Hant.lproj"),
                .folderReference(path: "XLocale/Resources/Localizations/en.lproj"),
                .folderReference(path: "XLocale/Resources/Localizations/ja.lproj")
            ],
            entitlements: .dictionary([
                "com.apple.security.app-sandbox": false,
                "com.apple.security.files.user-selected.read-write": true,
                "com.apple.security.network.client": true
            ]),
            dependencies: [
                .package(product: "Defaults"),
                .package(product: "SwiftUIX"),
                .package(product: "SwifterSwift"),
                .package(product: "OpenAI")
            ]
        ),
        
        // Tests
        .target(
            name: "XLocaleTests",
            destinations: [.mac],
            product: .unitTests,
            bundleId: "com.linhey.xlocale.tests",
            deploymentTargets: .macOS("13.0"),
            infoPlist: .default,
            sources: ["XLocaleTests/**"],
            resources: [
                .folderReference(path: "XLocaleTests/TestResources")
            ],
            dependencies: [
                .target(name: "XLocale")
            ]
        )
    ]
)
