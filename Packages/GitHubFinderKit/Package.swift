// swift-tools-version: 6.2
//
// GitHubFinderKit
// Now in Android (NiA) 風のモジュール分割を iOS で実現するための local Swift Package。
// アプリ本体（Xcode App target）からは複数の library product を import する。
// レイヤ依存:
//   Domain  ← Data ← Feature*
//                  ← DesignSystem ← Feature*
//   Domain ← DesignSystem
// すべての Feature target は Domain / Data / DesignSystem に依存し、Feature 同士は不参照。
//
// 隔離: Feature target は既定の隔離を指定しない（nonisolated）。`@Reducer` マクロが生成する準拠が
//   既定 MainActor 隔離ではコンパイルできないため。View は `View` プロトコル経由で MainActor に隔離される。
//
// ローカライズ: Reducer / State の String(localized:) は各 target の Resources/Localizable.xcstrings と
// `bundle: #bundle` で解決する。
// view 層（Text / Button / Label 等）も同じ target のカタログで、`Text("…", bundle: #bundle)` や
//   `LocalizedStringResource("…", bundle: #bundle)` を使って解決する。
//   App target（GitHubFinder/・FavoriteWidget/）専用の文言だけが App 側のカタログに残る。

import PackageDescription

let package = Package(
    name: "GitHubFinderKit",
    defaultLocalization: "ja",
    platforms: [
        .iOS(.v26),
    ],
    products: [
        .library(name: "GitHubFinderDomain", targets: ["GitHubFinderDomain"]),
        .library(name: "GitHubFinderData", targets: ["GitHubFinderData"]),
        .library(name: "GitHubFinderDesignSystem", targets: ["GitHubFinderDesignSystem"]),
        .library(name: "FeatureSearch", targets: ["FeatureSearch"]),
        .library(name: "FeatureFavorite", targets: ["FeatureFavorite"]),
        .library(name: "FeatureSettings", targets: ["FeatureSettings"]),
        .library(name: "FeatureTutorial", targets: ["FeatureTutorial"]),
    ],
    dependencies: [
        .package(
            url: "https://github.com/pointfreeco/swift-composable-architecture",
            from: "1.26.2",
            traits: ["ComposableArchitecture2Deprecations"]
        ),
        .package(url: "https://github.com/pointfreeco/swift-dependencies", from: "1.4.0"),
    ],
    targets: [
        // MARK: - Core layers
        .target(
            name: "GitHubFinderDomain",
            path: "Sources/GitHubFinderDomain",
            resources: [.process("Resources")],
            swiftSettings: [
                .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
            ],
        ),
        .target(
            name: "GitHubFinderData",
            dependencies: [
                "GitHubFinderDomain",
                .product(name: "Dependencies", package: "swift-dependencies"),
                .product(name: "DependenciesMacros", package: "swift-dependencies"),
            ],
            path: "Sources/GitHubFinderData",
            swiftSettings: [
                .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
            ],
        ),
        .target(
            name: "GitHubFinderDesignSystem",
            dependencies: ["GitHubFinderDomain"],
            path: "Sources/GitHubFinderDesignSystem",
            resources: [.process("Resources")],
            swiftSettings: [
                .defaultIsolation(MainActor.self),
                .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
                .enableUpcomingFeature("InferIsolatedConformances"),
            ],
        ),

        // MARK: - Feature layers
        .target(
            name: "FeatureSearch",
            dependencies: [
                "GitHubFinderDomain",
                "GitHubFinderData",
                "GitHubFinderDesignSystem",
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
            ],
            path: "Sources/FeatureSearch",
            resources: [.process("Resources")],
            swiftSettings: [
                .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
                .enableUpcomingFeature("InferIsolatedConformances"),
            ],
        ),
        .target(
            name: "FeatureFavorite",
            dependencies: [
                "GitHubFinderDomain",
                "GitHubFinderData",
                "GitHubFinderDesignSystem",
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
            ],
            path: "Sources/FeatureFavorite",
            resources: [.process("Resources")],
            swiftSettings: [
                .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
                .enableUpcomingFeature("InferIsolatedConformances"),
            ],
        ),
        .target(
            name: "FeatureSettings",
            dependencies: [
                "GitHubFinderDesignSystem",
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
            ],
            path: "Sources/FeatureSettings",
            resources: [.process("Resources")],
            swiftSettings: [
                .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
                .enableUpcomingFeature("InferIsolatedConformances"),
            ],
        ),
        .target(
            name: "FeatureTutorial",
            dependencies: [
                "GitHubFinderDesignSystem",
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
            ],
            path: "Sources/FeatureTutorial",
            resources: [.process("Resources")],
            swiftSettings: [
                .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
                .enableUpcomingFeature("InferIsolatedConformances"),
            ],
        ),
    ]
)
