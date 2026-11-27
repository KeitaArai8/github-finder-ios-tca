/*
 Abstract:
 アプリケーションのエントリポイント。ルートの Store を 1 つ作り、AppRootView へ渡す。
 Reducer が使う依存（検索・お気に入り・検索履歴・ネットワーク監視・チュートリアル）の本番実装は、
 各依存クライアントの `liveValue` が組み立てる。
 */

import SwiftUI
import ComposableArchitecture

@main
struct GitHubFinderApp: App {
    private static let store = Store(initialState: AppFeature.State()) {
        AppFeature()
    }

    var body: some Scene {
        WindowGroup {
            // ユニットテストはこのアプリをホストにして走る。テスト中は本物の画面と依存を動かさない
            if TestContext.current == nil {
                AppRootView(store: Self.store)
            }
        }
    }
}
