/*
 Abstract:
 FavoriteFeature の状態遷移を TestStore でテストする。
 */

import ComposableArchitecture
import Foundation
import Testing
import GitHubFinderDomain
import GitHubFinderData
import GitHubFinderDesignSystem
@testable import FeatureFavorite

@Suite("FavoriteFeature")
@MainActor
struct FavoriteFeatureTests {

    // MARK: - 読み込み

    @Test("初期状態はidleである")
    func initialStateIsIdle() {
        // Arrange & Act: デフォルトの初期状態を生成
        let state = FavoriteFeature.State(favorites: Shared(value: []))

        // Assert: idle状態でアラート等も出ていない
        #expect(state.viewState == .idle)
        #expect(state.destination == nil)
    }

    @Test("初回読み込み中は loading で、お気に入りがあれば完了後に loaded になる")
    func taskShowsLoadingThenLoaded() async {
        // Arrange: お気に入り1件を返すお気に入りクライアント
        let gate = EffectGate()
        let favorite = TestData.makeFavorite(id: 1)
        let store = TestStore(initialState: FavoriteFeature.State(favorites: Shared(value: []))) {
            FavoriteFeature()
        } withDependencies: {
            $0.favoriteClient.refresh = {
                await gate.wait()
                return [favorite]
            }
        }

        // Act: 画面表示時の読み込みを開始
        await store.send(.view(.task)) {
            $0.hasStartedLoading = true
        }
        gate.open()

        // Assert: 読み込みが終わるまでは loading
        #expect(store.state.viewState == .loading)

        // Assert: 完了後は 1 件の loaded
        await store.receive(\.internal.loadResponse) {
            $0.$favorites.withLock { $0 = [favorite] }
            $0.hasLoaded = true
        }
        #expect(store.state.viewState == .loaded([favorite]))
        await store.finish()
    }

    @Test("お気に入りが空の場合empty状態になる")
    func taskWithNoFavoritesTransitionsToEmpty() async {
        // Arrange: 空の一覧を返すお気に入りクライアント
        let gate = EffectGate()
        let store = TestStore(initialState: FavoriteFeature.State(favorites: Shared(value: []))) {
            FavoriteFeature()
        } withDependencies: {
            $0.favoriteClient.refresh = {
                await gate.wait()
                return []
            }
        }

        // Act: 画面表示時の読み込みを実行
        await store.send(.view(.task)) {
            $0.hasStartedLoading = true
        }
        gate.open()
        await store.receive(\.internal.loadResponse) {
            $0.hasLoaded = true
        }

        // Assert: empty状態
        #expect(store.state.viewState == .empty)
        await store.finish()
    }

    @Test("引っ張って更新で最新データに更新される")
    func refreshPulledReloadsLatestData() async {
        // Arrange: お気に入り1件のloaded状態と、2件に増えた一覧を返すお気に入りクライアント
        let gate = EffectGate()
        let favorite1 = TestData.makeFavorite(id: 1, fullName: "owner/repo1", savedAt: Date(timeIntervalSince1970: 2_000))
        let favorite2 = TestData.makeFavorite(id: 2, fullName: "owner/repo2", savedAt: Date(timeIntervalSince1970: 1_000))
        var state = FavoriteFeature.State(favorites: Shared(value: []))
        state.hasStartedLoading = true
        state.hasLoaded = true
        state.$favorites.withLock { $0 = [favorite1] }
        let store = TestStore(initialState: state) {
            FavoriteFeature()
        } withDependencies: {
            $0.favoriteClient.refresh = {
                await gate.wait()
                return [favorite1, favorite2]
            }
        }

        // Act: 引っ張って更新
        await store.send(.view(.refreshPulled))
        gate.open()

        // Assert: 2件に更新される
        await store.receive(\.internal.loadResponse) {
            $0.$favorites.withLock { $0 = [favorite1, favorite2] }
        }
        #expect(store.state.viewState == .loaded([favorite1, favorite2]))
        await store.finish()
    }

    // MARK: - スワイプ削除

    @Test("お気に入り削除後にリストが更新される")
    func swipeDeleteUpdatesList() async {
        // Arrange: お気に入り2件のloaded状態と、削除された ID を記録するお気に入りクライアント
        let gate = EffectGate()
        let favorite1 = TestData.makeFavorite(id: 1, fullName: "owner/repo1")
        let favorite2 = TestData.makeFavorite(id: 2, fullName: "owner/repo2")
        let removedIDs = LockIsolated<[Int]>([])
        var state = FavoriteFeature.State(favorites: Shared(value: []))
        state.hasStartedLoading = true
        state.hasLoaded = true
        state.$favorites.withLock { $0 = [favorite1, favorite2] }
        let store = TestStore(initialState: state) {
            FavoriteFeature()
        } withDependencies: {
            $0.favoriteClient.remove = { id in
                await gate.wait()
                removedIDs.withValue { $0.append(id) }
                return [favorite2]
            }
        }

        // Act: id=1 の行をスワイプ削除
        await store.send(.view(.rowsSwipeDeleted(ids: [1])))
        gate.open()

        // Assert: id=1 で remove が1回呼ばれ、残りの1件だけが表示される
        await store.receive(\.internal.removeResponse) {
            $0.$favorites.withLock { $0 = [favorite2] }
        }
        #expect(store.state.viewState == .loaded([favorite2]))
        #expect(removedIDs.value == [1])
        await store.finish()
    }

    @Test("最後の1件を削除するとempty状態になる")
    func swipeDeleteLastFavoriteTransitionsToEmpty() async {
        // Arrange: お気に入り1件のloaded状態と、削除後に空の一覧を返すお気に入りクライアント
        let gate = EffectGate()
        var state = FavoriteFeature.State(favorites: Shared(value: []))
        state.hasStartedLoading = true
        state.hasLoaded = true
        state.$favorites.withLock { $0 = [TestData.makeFavorite(id: 1)] }
        let store = TestStore(initialState: state) {
            FavoriteFeature()
        } withDependencies: {
            $0.favoriteClient.remove = { _ in
                await gate.wait()
                return []
            }
        }

        // Act: 最後の1件をスワイプ削除
        await store.send(.view(.rowsSwipeDeleted(ids: [1])))
        gate.open()
        await store.receive(\.internal.removeResponse) {
            $0.$favorites.withLock { $0 = [] }
        }

        // Assert: empty状態になる
        #expect(store.state.viewState == .empty)
        await store.finish()
    }

    @Test("削除失敗時にエラーアラートが表示されリストが維持される")
    func swipeDeleteFailureShowsAlertAndKeepsList() async {
        // Arrange: お気に入り1件のloaded状態と、削除に失敗するお気に入りクライアント
        let favorite = TestData.makeFavorite(id: 1)
        var state = FavoriteFeature.State(favorites: Shared(value: []))
        state.hasStartedLoading = true
        state.hasLoaded = true
        state.$favorites.withLock { $0 = [favorite] }
        let store = TestStore(initialState: state) {
            FavoriteFeature()
        } withDependencies: {
            $0.favoriteClient.remove = { _ in throw AppError.unknown("Mock error") }
        }

        // Act: スワイプ削除（失敗する）
        await store.send(.view(.rowsSwipeDeleted(ids: [1])))

        // Assert: loaded状態のまま、エラーアラートが表示される
        await store.receive(\.internal.removeFailed) {
            $0.destination = .alert(FavoriteFeature.removeFailedAlert)
        }
        #expect(store.state.viewState == .loaded([favorite]))
        await store.finish()
    }

    @Test("エラーアラートを閉じると表示状態がクリアされる")
    func dismissAlertClearsDestination() async {
        // Arrange: 削除失敗のアラートを表示中
        var state = FavoriteFeature.State(favorites: Shared(value: []))
        state.destination = .alert(FavoriteFeature.removeFailedAlert)
        let store = TestStore(initialState: state) {
            FavoriteFeature()
        }

        // Act: アラートを閉じる
        await store.send(.destination(.dismiss)) {
            // Assert: アラートの表示状態がクリアされる
            $0.destination = nil
        }
        await store.finish()
    }

    // MARK: - リポジトリを開く

    @Test("通常モードで行をタップすると GitHub ページを Safari シートで開く")
    func rowTappedPresentsSafari() async throws {
        // Arrange: owner/repo を1件表示中のloaded状態（通常モード）
        var state = FavoriteFeature.State(favorites: Shared(value: []))
        state.hasStartedLoading = true
        state.hasLoaded = true
        state.$favorites.withLock { $0 = [TestData.makeFavorite(id: 1, fullName: "owner/repo")] }
        let store = TestStore(initialState: state) {
            FavoriteFeature()
        }
        let url = try #require(URL(string: "https://github.com/owner/repo"))

        // Act: 行をタップ
        await store.send(.view(.rowTapped(id: 1))) {
            // Assert: リポジトリの GitHub ページが Safari シートの表示対象になる
            $0.destination = .safari(SafariDestination(url: url))
        }
        await store.finish()
    }

    // MARK: - 編集モード（複数選択・一括削除）

    @Test("編集ボタンで編集モードになる")
    func editButtonActivatesEditMode() async {
        // Arrange: お気に入り1件のloaded状態
        var state = FavoriteFeature.State(favorites: Shared(value: []))
        state.hasStartedLoading = true
        state.hasLoaded = true
        state.$favorites.withLock { $0 = [TestData.makeFavorite(id: 1)] }
        let store = TestStore(initialState: state) {
            FavoriteFeature()
        }

        // Act: 編集ボタンをタップ
        await store.send(.view(.editButtonTapped)) {
            $0.isEditModeRequested = true
        }

        // Assert: 編集モードになり、選択は空
        #expect(store.state.isEditMode == true)
        #expect(store.state.selectedIDs.isEmpty)
        await store.finish()
    }

    @Test("loaded状態でないときは編集ボタンが無視される")
    func editButtonIgnoredWhenNotLoaded() async {
        // Arrange: お気に入り0件のempty状態
        var state = FavoriteFeature.State(favorites: Shared(value: []))
        state.hasStartedLoading = true
        state.hasLoaded = true
        let store = TestStore(initialState: state) {
            FavoriteFeature()
        }

        // Act: 編集モード開始を試みる
        await store.send(.view(.editButtonTapped))

        // Assert: 編集モードに入らない
        #expect(store.state.isEditMode == false)
        await store.finish()
    }

    @Test("完了ボタンで編集モードが終わり選択がクリアされる")
    func doneButtonResetsEditMode() async {
        // Arrange: お気に入り2件・編集モードで id=1 を選択済み
        var state = FavoriteFeature.State(favorites: Shared(value: []))
        state.hasStartedLoading = true
        state.hasLoaded = true
        state.$favorites.withLock { $0 = [TestData.makeFavorite(id: 1), TestData.makeFavorite(id: 2)] }
        state.isEditModeRequested = true
        state.storedSelectedIDs = [1]
        let store = TestStore(initialState: state) {
            FavoriteFeature()
        }

        // Act: 完了ボタンをタップ
        await store.send(.view(.doneButtonTapped)) {
            $0.isEditModeRequested = false
            $0.storedSelectedIDs = []
        }

        // Assert: 編集モードが終わり、選択もクリアされる
        #expect(store.state.isEditMode == false)
        #expect(store.state.selectedIDs.isEmpty)
        await store.finish()
    }

    @Test("編集モードで行をタップすると選択状態がトグルされる")
    func rowTappedInEditModeTogglesSelection() async {
        // Arrange: お気に入り1件（id=42）・編集モードで未選択
        var state = FavoriteFeature.State(favorites: Shared(value: []))
        state.hasStartedLoading = true
        state.hasLoaded = true
        state.$favorites.withLock { $0 = [TestData.makeFavorite(id: 42)] }
        state.isEditModeRequested = true
        let store = TestStore(initialState: state) {
            FavoriteFeature()
        }

        // Act 1: id=42 の行をタップ
        await store.send(.view(.rowTapped(id: 42))) {
            $0.storedSelectedIDs = [42]
        }

        // Assert 1: 選択された
        #expect(store.state.selectedIDs == [42])

        // Act 2: 同じ行を再度タップ
        await store.send(.view(.rowTapped(id: 42))) {
            $0.storedSelectedIDs = []
        }

        // Assert 2: 選択解除（Safari シートは開かない）
        #expect(store.state.selectedIDs.isEmpty)
        await store.finish()
    }

    @Test("全選択ボタンは未選択状態から全お気に入りを選択する")
    func selectAllButtonFromEmptySelectsEveryItem() async {
        // Arrange: お気に入り3件・編集モードで未選択
        var state = FavoriteFeature.State(favorites: Shared(value: []))
        state.hasStartedLoading = true
        state.hasLoaded = true
        state.$favorites.withLock {
            $0 = [
                TestData.makeFavorite(id: 1),
                TestData.makeFavorite(id: 2),
                TestData.makeFavorite(id: 3),
            ]
        }
        state.isEditModeRequested = true
        let store = TestStore(initialState: state) {
            FavoriteFeature()
        }
        // Arrange: 未選択時のボタンタイトルを基準にする（ロケールに依存させない）
        let selectAllTitle = store.state.selectAllButtonTitle

        // Act: 全選択ボタンをタップ
        await store.send(.view(.selectAllButtonTapped)) {
            $0.storedSelectedIDs = [1, 2, 3]
        }

        // Assert: 全 ID が選択され、ボタンタイトルが全解除側に変わる
        #expect(store.state.selectedIDs == [1, 2, 3])
        #expect(store.state.isAllSelected == true)
        #expect(store.state.selectAllButtonTitle != selectAllTitle)
        await store.finish()
    }

    @Test("全選択ボタンは全選択状態から全解除へ切り替える")
    func selectAllButtonFromAllToEmpty() async {
        // Arrange: お気に入り2件・編集モードで全選択済み
        var state = FavoriteFeature.State(favorites: Shared(value: []))
        state.hasStartedLoading = true
        state.hasLoaded = true
        state.$favorites.withLock { $0 = [TestData.makeFavorite(id: 1), TestData.makeFavorite(id: 2)] }
        state.isEditModeRequested = true
        state.storedSelectedIDs = [1, 2]
        let store = TestStore(initialState: state) {
            FavoriteFeature()
        }
        // Arrange: 全選択時のボタンタイトルを基準にする（ロケールに依存させない）
        let deselectAllTitle = store.state.selectAllButtonTitle

        // Act: 全選択（全解除）ボタンをタップ
        await store.send(.view(.selectAllButtonTapped)) {
            $0.storedSelectedIDs = []
        }

        // Assert: 選択が空になり、ボタンタイトルが全選択側に戻る
        #expect(store.state.selectedIDs.isEmpty)
        #expect(store.state.isAllSelected == false)
        #expect(store.state.selectAllButtonTitle != deselectAllTitle)
        await store.finish()
    }

    @Test("全選択ボタンは部分選択状態から全選択へ切り替える（iOS Photos 同等）")
    func selectAllButtonFromPartialToAll() async {
        // Arrange: お気に入り3件・編集モードで id=2 のみ選択
        var state = FavoriteFeature.State(favorites: Shared(value: []))
        state.hasStartedLoading = true
        state.hasLoaded = true
        state.$favorites.withLock {
            $0 = [
                TestData.makeFavorite(id: 1),
                TestData.makeFavorite(id: 2),
                TestData.makeFavorite(id: 3),
            ]
        }
        state.isEditModeRequested = true
        state.storedSelectedIDs = [2]
        let store = TestStore(initialState: state) {
            FavoriteFeature()
        }

        // Act: 部分選択中に全選択ボタンをタップ
        await store.send(.view(.selectAllButtonTapped)) {
            $0.storedSelectedIDs = [1, 2, 3]
        }

        // Assert: 全選択になる
        #expect(store.state.selectedIDs == [1, 2, 3])
        #expect(store.state.isAllSelected == true)
        await store.finish()
    }

    @Test("全選択はフィルタ後の表示件数を対象にする")
    func selectAllRespectsLanguageFilter() async {
        // Arrange: Swift と Kotlin が混在し、Swift にフィルタした編集モード
        var state = FavoriteFeature.State(favorites: Shared(value: []))
        state.hasStartedLoading = true
        state.hasLoaded = true
        state.$favorites.withLock {
            $0 = [
                TestData.makeFavorite(id: 1, language: "Swift"),
                TestData.makeFavorite(id: 2, language: "Kotlin"),
                TestData.makeFavorite(id: 3, language: "Swift"),
            ]
        }
        state.isEditModeRequested = true
        state.storedFilterLanguage = "Swift"
        let store = TestStore(initialState: state) {
            FavoriteFeature()
        }

        // Act: 全選択ボタンをタップ
        await store.send(.view(.selectAllButtonTapped)) {
            $0.storedSelectedIDs = [1, 3]
        }

        // Assert: 非表示の Kotlin は含めず、表示中の Swift 2 件で isAllSelected が true
        #expect(store.state.selectedIDs == [1, 3])
        #expect(store.state.isAllSelected == true)
        await store.finish()
    }

    @Test("選択件数が0なら削除ボタンで確認ダイアログが出ない")
    func deleteSelectedButtonIgnoredWhenNoSelection() async {
        // Arrange: お気に入り1件・編集モードで選択なし
        var state = FavoriteFeature.State(favorites: Shared(value: []))
        state.hasStartedLoading = true
        state.hasLoaded = true
        state.$favorites.withLock { $0 = [TestData.makeFavorite(id: 1)] }
        state.isEditModeRequested = true
        let store = TestStore(initialState: state) {
            FavoriteFeature()
        }

        // Act: 削除ボタンをタップ
        await store.send(.view(.deleteSelectedButtonTapped))

        // Assert: 確認ダイアログは表示されない
        #expect(store.state.destination == nil)
        await store.finish()
    }

    @Test("選択ありなら削除ボタンで確認ダイアログが出る")
    func deleteSelectedButtonShowsConfirmation() async {
        // Arrange: お気に入り1件・編集モードで1件選択
        var state = FavoriteFeature.State(favorites: Shared(value: []))
        state.hasStartedLoading = true
        state.hasLoaded = true
        state.$favorites.withLock { $0 = [TestData.makeFavorite(id: 1)] }
        state.isEditModeRequested = true
        state.storedSelectedIDs = [1]
        let store = TestStore(initialState: state) {
            FavoriteFeature()
        }

        // Act: 削除ボタンをタップ
        await store.send(.view(.deleteSelectedButtonTapped)) {
            // Assert: 1件分の削除確認ダイアログが表示される
            $0.destination = .confirmationDialog(FavoriteFeature.deleteConfirmationDialog(count: 1))
        }
        await store.finish()
    }

    @Test("確認ダイアログで削除を確定すると選択中の項目が一括削除される")
    func confirmDeletionRemovesSelectedItems() async {
        // Arrange: お気に入り3件・編集モードで2件選択し、確認ダイアログを表示中。削除された ID を記録するお気に入りクライアント
        let gate = EffectGate()
        let favorite3 = TestData.makeFavorite(id: 3)
        let remaining = LockIsolated([TestData.makeFavorite(id: 1), TestData.makeFavorite(id: 2), favorite3])
        let removedIDs = LockIsolated<[Int]>([])
        var state = FavoriteFeature.State(favorites: Shared(value: []))
        state.hasStartedLoading = true
        state.hasLoaded = true
        state.$favorites.withLock { $0 = remaining.value }
        state.isEditModeRequested = true
        state.storedSelectedIDs = [1, 2]
        state.destination = .confirmationDialog(FavoriteFeature.deleteConfirmationDialog(count: 2))
        let store = TestStore(initialState: state) {
            FavoriteFeature()
        } withDependencies: {
            $0.favoriteClient.remove = { id in
                await gate.wait()
                removedIDs.withValue { $0.append(id) }
                return remaining.withValue {
                    $0.removeAll { $0.id == id }
                    return $0
                }
            }
        }

        // Act: 確認ダイアログで「削除」を選ぶ
        await store.send(.destination(.presented(.confirmationDialog(.confirmDeletion)))) {
            $0.destination = nil
        }
        gate.open()

        // Assert: 選択した2件が削除され、残り1件・選択クリア・確認ダイアログ閉
        await store.receive(\.internal.bulkRemoveResponse) {
            $0.$favorites.withLock { $0 = [favorite3] }
            $0.storedSelectedIDs = []
        }
        #expect(removedIDs.value == [1, 2])
        #expect(store.state.viewState == .loaded([favorite3]))
        #expect(store.state.selectedIDs.isEmpty)
        await store.finish()
    }

    @Test("一括削除が途中で失敗すると、成功した分だけ反映してエラーアラートを表示する")
    func bulkDeleteFailureKeepsSucceededRemovals() async {
        // Arrange: お気に入り2件・編集モードで全選択し、確認ダイアログを表示中。id=1 の削除は成功し id=2 の削除は失敗するお気に入りクライアント
        let gate = EffectGate()
        let favorite2 = TestData.makeFavorite(id: 2)
        var state = FavoriteFeature.State(favorites: Shared(value: []))
        state.hasStartedLoading = true
        state.hasLoaded = true
        state.$favorites.withLock { $0 = [TestData.makeFavorite(id: 1), favorite2] }
        state.isEditModeRequested = true
        state.storedSelectedIDs = [1, 2]
        state.destination = .confirmationDialog(FavoriteFeature.deleteConfirmationDialog(count: 2))
        let store = TestStore(initialState: state) {
            FavoriteFeature()
        } withDependencies: {
            $0.favoriteClient.remove = { id in
                await gate.wait()
                if id == 2 { throw AppError.unknown("Mock error") }
                return [favorite2]
            }
        }

        // Act: 確認ダイアログで「削除」を選ぶ
        await store.send(.destination(.presented(.confirmationDialog(.confirmDeletion)))) {
            $0.destination = nil
        }
        gate.open()

        // Assert: 削除できた id=1 だけが一覧から消え、エラーアラートが表示される（選択と編集モードは維持）
        await store.receive(\.internal.removeFailed) {
            $0.$favorites.withLock { $0 = [favorite2] }
            $0.destination = .alert(FavoriteFeature.removeFailedAlert)
        }
        #expect(store.state.selectedIDs == [2])
        await store.finish()
    }

    @Test("全件削除すると編集モードが自動終了する")
    func bulkDeleteAllExitsEditMode() async {
        // Arrange: お気に入り2件・編集モードで全選択し、確認ダイアログを表示中
        let gate = EffectGate()
        let remaining = LockIsolated([TestData.makeFavorite(id: 1), TestData.makeFavorite(id: 2)])
        var state = FavoriteFeature.State(favorites: Shared(value: []))
        state.hasStartedLoading = true
        state.hasLoaded = true
        state.$favorites.withLock { $0 = remaining.value }
        state.isEditModeRequested = true
        state.storedSelectedIDs = [1, 2]
        state.destination = .confirmationDialog(FavoriteFeature.deleteConfirmationDialog(count: 2))
        let store = TestStore(initialState: state) {
            FavoriteFeature()
        } withDependencies: {
            $0.favoriteClient.remove = { id in
                await gate.wait()
                return remaining.withValue {
                    $0.removeAll { $0.id == id }
                    return $0
                }
            }
        }

        // Act: 確認ダイアログで「削除」を選ぶ
        await store.send(.destination(.presented(.confirmationDialog(.confirmDeletion)))) {
            $0.destination = nil
        }
        gate.open()
        await store.receive(\.internal.bulkRemoveResponse) {
            $0.$favorites.withLock { $0 = [] }
            $0.storedSelectedIDs = []
            $0.isEditModeRequested = false
        }

        // Assert: empty に遷移し、編集モードが自動終了
        #expect(store.state.viewState == .empty)
        #expect(store.state.isEditMode == false)
        await store.finish()
    }

    @Test("お気に入りが空になって編集モードが終わった後、お気に入りが増えても編集モード・選択は戻らない")
    func editModeAndSelectionDoNotComeBackAfterEmptied() async {
        // Arrange: 一括削除で全件空になり編集モードが終了した直後の状態と、1件増えた一覧を返すお気に入りクライアント
        let gate = EffectGate()
        let favorite = TestData.makeFavorite(id: 3)
        var state = FavoriteFeature.State(favorites: Shared(value: []))
        state.hasStartedLoading = true
        state.hasLoaded = true
        let store = TestStore(initialState: state) {
            FavoriteFeature()
        } withDependencies: {
            $0.favoriteClient.refresh = {
                await gate.wait()
                return [favorite]
            }
        }

        // Act: 空になった後にお気に入りが1件増えて再読み込みされる
        await store.send(.view(.refreshPulled))
        gate.open()
        await store.receive(\.internal.loadResponse) {
            $0.$favorites.withLock { $0 = [favorite] }
        }

        // Assert: loaded に戻るが、編集モードは終了したまま・選択も空のまま
        #expect(store.state.viewState == .loaded([favorite]))
        #expect(store.state.isEditMode == false)
        #expect(store.state.selectedIDs.isEmpty)
        await store.finish()
    }

    // MARK: - ソート機能

    @Test("デフォルトのソートは savedAtDesc（保存が新しい順）")
    func defaultSortIsSavedAtDesc() async {
        // Arrange: savedAt が異なる 3 件を古い→新しい順で返すお気に入りクライアント
        let gate = EffectGate()
        let old = TestData.makeFavorite(id: 1, fullName: "owner/old", savedAt: Date(timeIntervalSince1970: 1_000))
        let mid = TestData.makeFavorite(id: 2, fullName: "owner/mid", savedAt: Date(timeIntervalSince1970: 2_000))
        let new = TestData.makeFavorite(id: 3, fullName: "owner/new", savedAt: Date(timeIntervalSince1970: 3_000))
        let store = TestStore(initialState: FavoriteFeature.State(favorites: Shared(value: []))) {
            FavoriteFeature()
        } withDependencies: {
            $0.favoriteClient.refresh = {
                await gate.wait()
                return [old, mid, new]
            }
        }

        // Act: 読み込み（デフォルト sortKey = savedAtDesc）
        await store.send(.view(.task)) {
            $0.hasStartedLoading = true
        }
        gate.open()
        await store.receive(\.internal.loadResponse) {
            $0.$favorites.withLock { $0 = [old, mid, new] }
            $0.hasLoaded = true
        }

        // Assert: 新しい順 (id=3, 2, 1) で並ぶ
        #expect(store.state.viewState == .loaded([new, mid, old]))
        #expect(store.state.sortKey == .savedAtDesc)
        await store.finish()
    }

    @Test("ソートキー starCountDesc で Star が多い順に並ぶ")
    func sortKeyStarCountDescOrdersByStars() async {
        // Arrange: starCount が異なる 3 件のloaded状態
        let star100 = TestData.makeFavorite(id: 1, fullName: "a/repo", starCount: 100)
        let star5000 = TestData.makeFavorite(id: 2, fullName: "b/repo", starCount: 5_000)
        let star500 = TestData.makeFavorite(id: 3, fullName: "c/repo", starCount: 500)
        var state = FavoriteFeature.State(favorites: Shared(value: []))
        state.hasStartedLoading = true
        state.hasLoaded = true
        state.$favorites.withLock { $0 = [star100, star5000, star500] }
        let store = TestStore(initialState: state) {
            FavoriteFeature()
        }

        // Act: ソートキー切替
        await store.send(.view(.sortKeySelected(.starCountDesc))) {
            $0.sortKey = .starCountDesc
        }

        // Assert: Star 多い順 (5000, 500, 100)
        #expect(store.state.viewState == .loaded([star5000, star500, star100]))
        await store.finish()
    }

    @Test("ソートキー fullNameAsc でリポジトリ名昇順に並ぶ")
    func sortKeyFullNameAscOrdersAlphabetically() async {
        // Arrange: 名前順がばらばらの 3 件のloaded状態
        let zoo = TestData.makeFavorite(id: 1, fullName: "zoo/repo")
        let apple = TestData.makeFavorite(id: 2, fullName: "apple/swift")
        let microsoft = TestData.makeFavorite(id: 3, fullName: "microsoft/vscode")
        var state = FavoriteFeature.State(favorites: Shared(value: []))
        state.hasStartedLoading = true
        state.hasLoaded = true
        state.$favorites.withLock { $0 = [zoo, apple, microsoft] }
        let store = TestStore(initialState: state) {
            FavoriteFeature()
        }

        // Act: ソートキー切替
        await store.send(.view(.sortKeySelected(.fullNameAsc))) {
            $0.sortKey = .fullNameAsc
        }

        // Assert: A→Z で並ぶ
        #expect(store.state.viewState == .loaded([apple, microsoft, zoo]))
        await store.finish()
    }

    // MARK: - 言語フィルタ

    @Test("言語チップのタップで指定言語のみに絞り込まれる")
    func filterChipFiltersByLanguage() async {
        // Arrange: Swift と Kotlin のお気に入りが混在するloaded状態（保存が新しい順に swift1, kotlin1, swift2）
        let swift1 = TestData.makeFavorite(id: 1, fullName: "a/swift1", language: "Swift", savedAt: Date(timeIntervalSince1970: 3_000))
        let kotlin1 = TestData.makeFavorite(id: 2, fullName: "b/kotlin1", language: "Kotlin", savedAt: Date(timeIntervalSince1970: 2_000))
        let swift2 = TestData.makeFavorite(id: 3, fullName: "c/swift2", language: "Swift", savedAt: Date(timeIntervalSince1970: 1_000))
        var state = FavoriteFeature.State(favorites: Shared(value: []))
        state.hasStartedLoading = true
        state.hasLoaded = true
        state.$favorites.withLock { $0 = [swift1, kotlin1, swift2] }
        let store = TestStore(initialState: state) {
            FavoriteFeature()
        }

        // Act: Swift のチップをタップ
        await store.send(.view(.filterChipTapped("Swift"))) {
            $0.storedFilterLanguage = "Swift"
        }

        // Assert: Swift の 2 件のみ
        #expect(store.state.viewState == .loaded([swift1, swift2]))
        #expect(store.state.filterLanguage == "Swift")
        await store.finish()
    }

    @Test("「すべて」チップのタップでフィルタが解除される")
    func allChipClearsFilter() async {
        // Arrange: Swift にフィルタ済みのloaded状態（保存が新しい順に swift, kotlin）
        let swift = TestData.makeFavorite(id: 1, language: "Swift", savedAt: Date(timeIntervalSince1970: 2_000))
        let kotlin = TestData.makeFavorite(id: 2, language: "Kotlin", savedAt: Date(timeIntervalSince1970: 1_000))
        var state = FavoriteFeature.State(favorites: Shared(value: []))
        state.hasStartedLoading = true
        state.hasLoaded = true
        state.$favorites.withLock { $0 = [swift, kotlin] }
        state.storedFilterLanguage = "Swift"
        let store = TestStore(initialState: state) {
            FavoriteFeature()
        }

        // Act: 「すべて」のチップをタップ
        await store.send(.view(.filterChipTapped(nil))) {
            $0.storedFilterLanguage = nil
        }

        // Assert: 全件が再表示される
        #expect(store.state.viewState == .loaded([swift, kotlin]))
        #expect(store.state.filterLanguage == nil)
        await store.finish()
    }

    @Test("選択中の言語チップをもう一度タップするとフィルタが解除される")
    func selectedChipTappedAgainClearsFilter() async {
        // Arrange: Swift にフィルタ済みのloaded状態
        var state = FavoriteFeature.State(favorites: Shared(value: []))
        state.hasStartedLoading = true
        state.hasLoaded = true
        state.$favorites.withLock { $0 = [TestData.makeFavorite(id: 1, language: "Swift")] }
        state.storedFilterLanguage = "Swift"
        let store = TestStore(initialState: state) {
            FavoriteFeature()
        }

        // Act: 選択中の Swift のチップをもう一度タップ
        await store.send(.view(.filterChipTapped("Swift"))) {
            // Assert: フィルタが解除される
            $0.storedFilterLanguage = nil
        }
        await store.finish()
    }

    @Test("フィルタ対象の言語が消失したら自動でクリアされる")
    func filterLanguageAutoClearsWhenLanguageGone() async {
        // Arrange: Swift にフィルタ済みのloaded状態と、Swift のお気に入りの削除後に Kotlin の1件だけを返すお気に入りクライアント
        let gate = EffectGate()
        let kotlin = TestData.makeFavorite(id: 2, language: "Kotlin")
        var state = FavoriteFeature.State(favorites: Shared(value: []))
        state.hasStartedLoading = true
        state.hasLoaded = true
        state.$favorites.withLock { $0 = [TestData.makeFavorite(id: 1, language: "Swift"), kotlin] }
        state.storedFilterLanguage = "Swift"
        let store = TestStore(initialState: state) {
            FavoriteFeature()
        } withDependencies: {
            $0.favoriteClient.remove = { _ in
                await gate.wait()
                return [kotlin]
            }
        }

        // Act: Swift のお気に入りをスワイプ削除
        await store.send(.view(.rowsSwipeDeleted(ids: [1])))
        gate.open()
        await store.receive(\.internal.removeResponse) {
            $0.$favorites.withLock { $0 = [kotlin] }
            $0.storedFilterLanguage = nil
        }

        // Assert: フィルタが自動クリアされ、Kotlin の 1 件が表示される
        #expect(store.state.filterLanguage == nil)
        #expect(store.state.viewState == .loaded([kotlin]))
        await store.finish()
    }

    @Test("フィルタ対象の言語が消失してクリアされた後、その言語が戻ってもフィルタは復活しない")
    func filterLanguageDoesNotComeBackAfterLanguageReturns() async {
        // Arrange: Swift のフィルタがクリアされた直後の状態（Kotlin 1件）と、Swift が再び増えた一覧を返すお気に入りクライアント
        let gate = EffectGate()
        let kotlin = TestData.makeFavorite(id: 2, language: "Kotlin", savedAt: Date(timeIntervalSince1970: 2_000))
        let swift = TestData.makeFavorite(id: 4, language: "Swift", savedAt: Date(timeIntervalSince1970: 1_000))
        var state = FavoriteFeature.State(favorites: Shared(value: []))
        state.hasStartedLoading = true
        state.hasLoaded = true
        state.$favorites.withLock { $0 = [kotlin] }
        let store = TestStore(initialState: state) {
            FavoriteFeature()
        } withDependencies: {
            $0.favoriteClient.refresh = {
                await gate.wait()
                return [kotlin, swift]
            }
        }

        // Act: Swift のお気に入りが再び増えて再読み込みされる
        await store.send(.view(.refreshPulled))
        gate.open()
        await store.receive(\.internal.loadResponse) {
            $0.$favorites.withLock { $0 = [kotlin, swift] }
        }

        // Assert: フィルタは nil のままで、Kotlin / Swift の 2 件が表示される
        #expect(store.state.filterLanguage == nil)
        #expect(store.state.viewState == .loaded([kotlin, swift]))
        await store.finish()
    }

    @Test("availableLanguages が重複なくソート済みで返る")
    func availableLanguagesIsDistinctAndSorted() {
        // Arrange: 言語の重複あり・未指定（nil）ありのお気に入り 4 件
        let state = FavoriteFeature.State(favorites: Shared(value: []))
        state.$favorites.withLock {
            $0 = [
                TestData.makeFavorite(id: 1, language: "Swift"),
                TestData.makeFavorite(id: 2, language: "Kotlin"),
                TestData.makeFavorite(id: 3, language: "Swift"),
                TestData.makeFavorite(id: 4, language: nil),
            ]
        }

        // Act: フィルタの選択肢を取得
        let languages = state.availableLanguages

        // Assert: 重複と nil を除き、名前順で返る
        #expect(languages == ["Kotlin", "Swift"])
    }
}
