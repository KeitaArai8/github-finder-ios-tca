/*
 Abstract:
 GitHubFinderDesignSystem のコンポーネントを単独で確認できる Storybook 的アプリ。
 本体アプリ（GitHubFinder.app）と完全に独立した Bundle ID で動作するため、
 DS コンポーネントの追加・修正をアプリ全体起動なしに検証できる。
 */

import SwiftUI

@main
struct DesignSystemCatalogApp: App {
    var body: some Scene {
        WindowGroup {
            CatalogContentView()
        }
    }
}
