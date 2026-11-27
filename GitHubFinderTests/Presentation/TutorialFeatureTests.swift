/*
 Abstract:
 TutorialFeature のステップ進行と完了処理を TestStore でテストする。
 */

import ComposableArchitecture
import Testing
@testable import FeatureTutorial

@Suite("TutorialFeature")
@MainActor
struct TutorialFeatureTests {

    @Test("次へボタンで次のステップへ進む")
    func nextButtonAdvancesStep() async {
        // Arrange: 最初のステップ（検索バー）を表示中
        let store = TestStore(initialState: TutorialFeature.State()) {
            TutorialFeature()
        }

        // Act: 「次へ」をタップ
        await store.send(.view(.nextButtonTapped)) {
            // Assert: 2 番目のステップ（ハートボタン）へ進む
            $0.currentStep = .favoriteButton
        }
        await store.finish()
    }

    @Test("現在のステップの対象 UI をタップすると次のステップへ進む")
    func targetTappedAdvancesStep() async {
        // Arrange: 最初のステップ（検索バー）を表示中
        let store = TestStore(initialState: TutorialFeature.State()) {
            TutorialFeature()
        }

        // Act: 検索バーのモックをタップ
        await store.send(.view(.targetTapped(.searchBar))) {
            // Assert: 2 番目のステップ（ハートボタン）へ進む
            $0.currentStep = .favoriteButton
        }
        await store.finish()
    }

    @Test("現在のステップと違う対象 UI をタップしても進まない")
    func targetTappedForOtherStepDoesNothing() async {
        // Arrange: 最初のステップ（検索バー）を表示中
        let store = TestStore(initialState: TutorialFeature.State()) {
            TutorialFeature()
        }

        // Act: 現在のステップの対象ではないお気に入りタブのモックをタップ
        await store.send(.view(.targetTapped(.favoriteTab)))

        // Assert: ステップは変わらず、完了の保存も通知も起きない
        await store.finish()
    }

    @Test("最後のステップを終えると完了を保存して親へ通知する")
    func lastStepCompletesTutorial() async {
        // Arrange: 最後のステップ（お気に入りタブ）を表示中。完了の保存回数を記録するチュートリアルクライアント
        let markCompletedCallCount = LockIsolated(0)
        var state = TutorialFeature.State()
        state.currentStep = .favoriteTab
        let store = TestStore(initialState: state) {
            TutorialFeature()
        } withDependencies: {
            $0.tutorialClient.markCompleted = { markCompletedCallCount.withValue { $0 += 1 } }
        }

        // Act: 「次へ」をタップ
        await store.send(.view(.nextButtonTapped))

        // Assert: 完了が1回保存され、親へ完了が通知される
        await store.receive(\.delegate.completed)
        #expect(markCompletedCallCount.value == 1)
        await store.finish()
    }

    @Test("スキップすると途中のステップでも完了を保存して親へ通知する")
    func skipButtonCompletesTutorial() async {
        // Arrange: 最初のステップ（検索バー）を表示中。完了の保存回数を記録するチュートリアルクライアント
        let markCompletedCallCount = LockIsolated(0)
        let store = TestStore(initialState: TutorialFeature.State()) {
            TutorialFeature()
        } withDependencies: {
            $0.tutorialClient.markCompleted = { markCompletedCallCount.withValue { $0 += 1 } }
        }

        // Act: 「スキップ」をタップ
        await store.send(.view(.skipButtonTapped))

        // Assert: 完了が1回保存され、親へ完了が通知される
        await store.receive(\.delegate.completed)
        #expect(markCompletedCallCount.value == 1)
        await store.finish()
    }
}
