import ProjectDescription

let dependencies = Dependencies(
    swiftPackageManager: [
        .remote(url: "https://github.com/SwiftUIX/SwiftUIX.git", requirement: .upToNextMajor(from: "0.2.3")),
        .remote(url: "https://github.com/MacPaw/OpenAI.git", requirement: .upToNextMajor(from: "0.3.0"))
    ],
    platforms: [.macOS]
) 