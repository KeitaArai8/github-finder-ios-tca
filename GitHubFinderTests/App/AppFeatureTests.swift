/*
 Abstract:
 AppFeature（ルート Reducer）のチュートリアル表示判定とネットワーク接続状態の反映を TestStore でテストする。
 */

import ComposableArchitecture
import Testing
import GitHubFinderData
import FeatureTutorial
@testable import FeatureSearch
@testable import FeatureFavorite
@testable import GitHubFinder

@Suite("AppFeature")
@MainActor
struct AppFeatureTests {

    @Test("チュートリアル未完了で起動するとチュートリアルを表示する")
    func taskPresentsTutorialWhenNotCompleted() async {
        // Arrange: チュートリアル未完了。接続状態は何も流さず終わるネットワーククライアント
        let store = TestStore(initialState: AppFeature.State()) {
            AppFeature()
        } withDependencies: {
            $0.tutorialClient.hasCompleted = { false }
            $0.networkClient.connectivity = { .finished }
        }

        // Act: 画面表示時の処理を実行
        await store.send(.view(.task)) {
            // Assert: チュートリアルが最初のステップから表示される
            $0.tutorial = TutorialFeature.State()
        }
        await store.finish()
    }

    @Test("チュートリアル完了済みで起動するとメイン画面のままになる")
    func taskKeepsMainWhenTutorialCompleted() async {
        // Arrange: チュートリアル完了済み。接続状態は何も流さず終わるネットワーククライアント
        let store = TestStore(initialState: AppFeature.State()) {
            AppFeature()
        } withDependencies: {
            $0.tutorialClient.hasCompleted = { true }
            $0.networkClient.connectivity = { .finished }
        }

        // Act: 画面表示時の処理を実行
        await store.send(.view(.task))

        // Assert: チュートリアルは表示されない
        #expect(store.state.tutorial == nil)
        await store.finish()
    }

    @Test("チュートリアルが完了するとメイン画面へ切り替わる")
    func tutorialCompletedDismissesTutorial() async {
        // Arrange: チュートリアルの最後のステップを表示中
        var state = AppFeature.State()
        state.tutorial = TutorialFeature.State()
        state.tutorial?.currentStep = .favoriteTab
        let store = TestStore(initialState: state) {
            AppFeature()
        } withDependencies: {
            $0.tutorialClient.markCompleted = {}
        }

        // Act: 最後のステップで「次へ」をタップ
        await store.send(.tutorial(.view(.nextButtonTapped)))

        // Assert: 完了の通知を受けてチュートリアルが閉じる
        await store.receive(\.tutorial.delegate.completed) {
            $0.tutorial = nil
        }
        await store.finish()
    }

    @Test("検索画面でのお気に入り追加が、お気に入り画面の一覧へすぐ反映される")
    func favoriteAddedInSearchIsSharedWithFavoriteTab() async {
        // Arrange: 検索結果1件（お気に入り未登録）を表示中。追加後の一覧を返すお気に入りクライアント
        let gate = EffectGate()
        let favorite = TestData.makeFavorite(id: 42)
        var state = AppFeature.State()
        state.search.searchQuery = "test"
        state.search.lastSearchedQuery = "test"
        state.search.items = [TestData.makeRepository(id: 42)]
        let store = TestStore(initialState: state) {
            AppFeature()
        } withDependencies: {
            $0.favoriteClient.add = { _ in
                await gate.wait()
                return [favorite]
            }
        }

        // Act: 検索画面でハートボタンをタップ
        await store.send(.search(.view(.favoriteButtonTapped(id: 42))))
        gate.open()
        await store.receive(\.search.internal.favoritesResponse) {
            $0.search.$favorites.withLock { $0 = [favorite] }
        }

        // Assert: お気に入り画面の State も、再読み込みなしで同じ一覧を指している
        #expect(store.state.favorite.favorites == [favorite])
        await store.finish()
    }

    @Test("ネットワーク接続状態の変化がオフライン表示の状態へ反映される")
    func connectivityChangesUpdateIsConnected() async {
        // Arrange: チュートリアル完了済み。テストから接続状態を流せるネットワーククライアント
        let (connectivity, continuation) = AsyncStream.makeStream(of: Bool.self)
        let store = TestStore(initialState: AppFeature.State()) {
            AppFeature()
        } withDependencies: {
            $0.tutorialClient.hasCompleted = { true }
            $0.networkClient.connectivity = { connectivity }
        }
        await store.send(.view(.task))

        // Act: オフラインになる
        continuation.yield(false)

        // Assert: 未接続として反映される
        await store.receive(\.internal.connectivityChanged) {
            $0.isConnected = false
        }

        // Act: オンラインへ戻る
        continuation.yield(true)

        // Assert: 接続中として反映される
        await store.receive(\.internal.connectivityChanged) {
            $0.isConnected = true
        }
        continuation.finish()
        await store.finish()
    }
}
