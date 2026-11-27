/*
 Abstract:
 アプリのルートView。チュートリアル表示判定とメイン画面の切替を行う。
 チュートリアルが有効な間はTutorialScreen（専用モック画面）を表示し、
 完了・スキップ後に本物のMainTabViewへ遷移する。
 オフライン時はアプリ最上部に OfflineBanner を safeAreaBar として差し込む。
 */

import SwiftUI
import ComposableArchitecture
import GitHubFinderDesignSystem
import FeatureTutorial

@ViewAction(for: AppFeature.self)
struct AppRootView: View {
    let store: StoreOf<AppFeature>

    var body: some View {
        Group {
            if let tutorialStore = store.scope(\.tutorial, action: \.tutorial) {
                TutorialScreen(store: tutorialStore)
            } else {
                // safeAreaBar はメイン画面だけに掛ける。チュートリアルまで包むと、バーのホストが
                // 上端の帯のタップを奪い、スキップボタンが反応しなくなる（チュートリアルはモック UI でバナー不要）
                MainTabView(store: store)
                // バナーの分だけコンテンツが下へ押し下げられ、スクロールエッジ効果も追従する
                .safeAreaBar(edge: .top) {
                    if !store.isConnected {
                        OfflineBanner()
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }
                }
            }
        }
        .animation(.easeInOut(duration: 0.25), value: store.isConnected)
        .task {
            // ネットワーク監視は View の表示中だけ続ける（View の消滅で Effect もキャンセルされる）
            await send(.task).finish()
        }
    }
}
