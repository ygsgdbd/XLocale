import ProjectDescription

let config = Config(
    plugins: [],
    generationOptions: .options(
        resolveDependenciesWithSystemScm: true,
        staticSideEffectsWarningTargets: .all,
        defaultConfiguration: "Debug"
    )
)
