/*
 Abstract:
 SearchFeature の状態遷移とビジネスロジックを TestStore でテストする。
 debounce の時間は TestClock で進めるため、実時間の待機に依存しない。
 */

import ComposableArchitecture
import Foundation
import Testing
import GitHubFinderDomain
import GitHubFinderData
import GitHubFinderDesignSystem
@testable import FeatureSearch

@Suite("SearchFeature")
@MainActor
struct SearchFeatureTests {

    // MARK: - 初期状態

    @Test("初期状態はidleである")
    func initialStateIsIdle() {
        // Arrange & Act: デフォルトの初期状態を生成
        let state = SearchFeature.State(favorites: Shared(value: []))

        // Assert: 全プロパティが初期値
        #expect(state.viewState == .idle)
        #expect(state.searchQuery == "")
        #expect(state.isLoadingMore == false)
        #expect(state.destination == nil)
    }

    @Test("初回起動時は検索前なので idle のまま")
    func taskBeforeAnySearchKeepsIdle() async {
        // Arrange: 未検索・お気に入り0件・履歴なしの初回起動状態
        let store = TestStore(initialState: SearchFeature.State(favorites: Shared(value: []))) {
            SearchFeature()
        } withDependencies: {
            $0.favoriteClient.refresh = { [] }
            $0.searchHistoryClient.history = { [] }
        }

        // Act: 画面表示時の読み込み（お気に入り・検索履歴）を実行
        await store.send(.view(.task))
        await store.receive(\.internal.loadResponse)

        // Assert: 検索結果0件でも .empty にならず .idle のまま（検索も実行されない）
        #expect(store.state.viewState == .idle)
        await store.finish()
    }

    // MARK: - 検索

    @Test("検索成功時にloaded状態になる")
    func searchSuccessTransitionsToLoaded() async {
        // Arrange: 検索結果1件を返す検索クライアント（呼び出し引数を記録する）
        let repository = TestData.makeRepository(id: 1)
        let clock = TestClock()
        let searchCalls = LockIsolated<[SearchCall]>([])
        let store = TestStore(initialState: SearchFeature.State(favorites: Shared(value: []))) {
            SearchFeature()
        } withDependencies: {
            $0.continuousClock = clock
            $0.searchClient.search = { query, page in
                searchCalls.withValue { $0.append(SearchCall(query: query, page: page)) }
                return TestData.makeSearchResult(items: [repository])
            }
            $0.favoriteClient.refresh = { [] }
            $0.searchHistoryClient.add = { [$0] }
        }

        // Act: クエリを入力し、debounce の 500ms が経過する
        await store.send(.view(.binding(.set(\.searchQuery, "swift")))) {
            $0.searchQuery = "swift"
        }
        await clock.advance(by: .milliseconds(500))
        await store.receive(\.internal.debounceCompleted) {
            $0.isSearching = true
            $0.lastSearchedQuery = "swift"
        }

        // Assert: loaded状態で検索結果が反映され、"swift" の 1 ページ目が検索されている
        await store.receive(\.internal.searchResponse) {
            $0.items = [repository]
            $0.history = ["swift"]
            $0.isSearching = false
        }
        #expect(store.state.viewState == .loaded([RepositoryDisplayItem(repository: repository, isFavorite: false)]))
        #expect(searchCalls.value == [SearchCall(query: "swift", page: 1)])
        await store.finish()
    }

    @Test("検索結果が空の場合empty状態になる")
    func searchEmptyResultTransitionsToEmpty() async {
        // Arrange: 空の検索結果を返す検索クライアント
        let clock = TestClock()
        let store = TestStore(initialState: SearchFeature.State(favorites: Shared(value: []))) {
            SearchFeature()
        } withDependencies: {
            $0.continuousClock = clock
            $0.searchClient.search = { _, _ in TestData.makeSearchResult(items: []) }
            $0.favoriteClient.refresh = { [] }
            $0.searchHistoryClient.add = { [$0] }
        }

        // Act: クエリを入力し、debounce の 500ms が経過する
        await store.send(.view(.binding(.set(\.searchQuery, "nonexistent")))) {
            $0.searchQuery = "nonexistent"
        }
        await clock.advance(by: .milliseconds(500))
        await store.receive(\.internal.debounceCompleted) {
            $0.isSearching = true
            $0.lastSearchedQuery = "nonexistent"
        }

        // Assert: 検索結果なしでempty状態
        await store.receive(\.internal.searchResponse) {
            $0.history = ["nonexistent"]
            $0.isSearching = false
        }
        #expect(store.state.viewState == .empty)
        await store.finish()
    }

    @Test("検索失敗時にerror状態になる")
    func searchFailureTransitionsToError() async {
        // Arrange: 通信エラーを投げる検索クライアント
        let clock = TestClock()
        let store = TestStore(initialState: SearchFeature.State(favorites: Shared(value: []))) {
            SearchFeature()
        } withDependencies: {
            $0.continuousClock = clock
            $0.searchClient.search = { _, _ in throw AppError.network }
        }

        // Act: クエリを入力し、debounce の 500ms が経過する
        await store.send(.view(.binding(.set(\.searchQuery, "test")))) {
            $0.searchQuery = "test"
        }
        await clock.advance(by: .milliseconds(500))
        await store.receive(\.internal.debounceCompleted) {
            $0.isSearching = true
            $0.lastSearchedQuery = "test"
        }

        // Assert: error状態に遷移し、失敗した検索は「検索済み」にならない
        await store.receive(\.internal.searchFailed) {
            $0.isSearching = false
            $0.lastSearchedQuery = nil
            $0.searchError = AppError.network.localizedDescription
        }
        #expect(store.state.viewState == .error(AppError.network.localizedDescription))
        await store.finish()
    }

    @Test("クエリを空にするとidle状態に戻る")
    func clearQueryResetsToIdle() async {
        // Arrange: "swift" で検索済みのloaded状態（検索結果1件・次ページあり）
        var state = SearchFeature.State(favorites: Shared(value: []))
        state.searchQuery = "swift"
        state.lastSearchedQuery = "swift"
        state.items = [TestData.makeRepository(id: 1)]
        state.hasNextPage = true
        let store = TestStore(initialState: state) {
            SearchFeature()
        }

        // Act: クエリを空にする
        await store.send(.view(.binding(.set(\.searchQuery, "")))) {
            $0.searchQuery = ""
            $0.lastSearchedQuery = nil
            $0.items = []
            $0.hasNextPage = false
        }

        // Assert: debounce を待たずに idle 状態へリセットされる
        #expect(store.state.viewState == .idle)
        await store.finish()
    }

    @Test("検索済みと同じクエリのまま画面が再表示されてもAPIは再呼び出しされない")
    func taskSkipsAlreadySearchedQuery() async {
        // Arrange: "swift" で検索済みのloaded状態（検索クライアントは未設定＝呼ばれたらテスト失敗）
        let repository = TestData.makeRepository(id: 1)
        var state = SearchFeature.State(favorites: Shared(value: []))
        state.searchQuery = "swift"
        state.lastSearchedQuery = "swift"
        state.items = [repository]
        let store = TestStore(initialState: state) {
            SearchFeature()
        } withDependencies: {
            $0.favoriteClient.refresh = { [] }
            $0.searchHistoryClient.history = { ["swift"] }
        }

        // Act: タブ復帰で画面表示時の読み込みが再度走る
        await store.send(.view(.task))
        await store.receive(\.internal.loadResponse) {
            $0.history = ["swift"]
        }

        // Assert: 検索は実行されず、loaded状態が維持される
        #expect(store.state.viewState == .loaded([RepositoryDisplayItem(repository: repository, isFavorite: false)]))
        await store.finish()
    }

    @Test("未検索のまま空白だけを入力しても状態を変えない")
    func blankQueryBeforeAnySearchKeepsState() async {
        // Arrange: 未検索の初期状態（検索クライアントは未設定＝呼ばれたらテスト失敗）
        let store = TestStore(initialState: SearchFeature.State(favorites: Shared(value: []))) {
            SearchFeature()
        }

        // Act: 空白のみを入力する
        await store.send(.view(.binding(.set(\.searchQuery, " ")))) {
            $0.searchQuery = " "
        }

        // Assert: idleのままAPIも呼ばれない
        #expect(store.state.viewState == .idle)
        await store.finish()
    }

    @Test("実行中の検索が入力の変化でキャンセルされた後は同じクエリで再検索できる")
    func searchRetriesSameQueryAfterCancellation() async {
        // Arrange: 1回目の検索は完了せず、2回目以降は検索結果1件を返す検索クライアント。"swift" の検索が実行中
        let repository = TestData.makeRepository(id: 1)
        let clock = TestClock()
        let searchCallCount = LockIsolated(0)
        var state = SearchFeature.State(favorites: Shared(value: []))
        state.searchQuery = "swift"
        let store = TestStore(initialState: state) {
            SearchFeature()
        } withDependencies: {
            $0.continuousClock = clock
            $0.searchClient.search = { _, _ in
                let callCount = searchCallCount.withValue { $0 += 1; return $0 }
                if callCount == 1 { try await Task.never() }
                return TestData.makeSearchResult(items: [repository])
            }
            $0.favoriteClient.refresh = { [] }
            $0.searchHistoryClient.add = { [$0] }
        }
        await store.send(.view(.refreshPulled)) {
            $0.isSearching = true
            $0.lastSearchedQuery = "swift"
        }

        // Act: 入力を変えて実行中の検索をキャンセルし、元のクエリへ戻して 500ms 待つ
        await store.send(.view(.binding(.set(\.searchQuery, "swif")))) {
            $0.searchQuery = "swif"
            $0.lastSearchedQuery = nil
        }
        await store.send(.view(.binding(.set(\.searchQuery, "swift")))) {
            $0.searchQuery = "swift"
        }
        await clock.advance(by: .milliseconds(500))
        await store.receive(\.internal.debounceCompleted) {
            $0.lastSearchedQuery = "swift"
        }

        // Assert: 2回目の検索が実行されloaded状態になる（loadingのまま固まらない）
        await store.receive(\.internal.searchResponse) {
            $0.items = [repository]
            $0.history = ["swift"]
            $0.isSearching = false
        }
        #expect(store.state.viewState == .loaded([RepositoryDisplayItem(repository: repository, isFavorite: false)]))
        #expect(searchCallCount.value == 2)
        await store.finish()
    }

    @Test("検索が CancellationError で終わっても error 状態にならない")
    func searchCancellationDoesNotShowError() async {
        // Arrange: CancellationError を投げる検索クライアント（Repository が URLError(.cancelled) から変換するエラー）
        var state = SearchFeature.State(favorites: Shared(value: []))
        state.searchQuery = "swift"
        let store = TestStore(initialState: state) {
            SearchFeature()
        } withDependencies: {
            $0.searchClient.search = { _, _ in throw CancellationError() }
        }

        // Act: 検索を実行
        await store.send(.view(.refreshPulled)) {
            $0.isSearching = true
            $0.lastSearchedQuery = "swift"
        }

        // Assert: error 状態にならず、同じクエリで再検索できるよう「検索済み」も取り消される
        await store.receive(\.internal.searchCancelled) {
            $0.lastSearchedQuery = nil
        }
        #expect(store.state.searchError == nil)
        #expect(store.state.viewState == .loading)
        await store.finish()
    }

    @Test("キャンセル済みの検索が通信エラーを返しても error 状態にならない")
    func searchErrorAfterCancellationDoesNotShowError() async {
        // Arrange: キャンセルされると通信エラーを投げる検索クライアント（キャンセル競合で .network に変換されたケース）。"swift" の検索が実行中
        var state = SearchFeature.State(favorites: Shared(value: []))
        state.searchQuery = "swift"
        let store = TestStore(initialState: state) {
            SearchFeature()
        } withDependencies: {
            $0.searchClient.search = { _, _ in
                try? await Task.never()
                throw AppError.network
            }
        }
        await store.send(.view(.refreshPulled)) {
            $0.isSearching = true
            $0.lastSearchedQuery = "swift"
        }

        // Act: クエリを空にして実行中の検索をキャンセルする
        await store.send(.view(.binding(.set(\.searchQuery, "")))) {
            $0.searchQuery = ""
            $0.isSearching = false
            $0.lastSearchedQuery = nil
        }

        // Assert: キャンセル後に届いた通信エラーは無視され、error 状態にならない
        await store.finish()
        #expect(store.state.viewState == .idle)
    }

    @Test("エラー後に画面が再表示されると同じクエリで再検索できる")
    func taskRetriesSameQueryAfterError() async {
        // Arrange: "swift" の検索が失敗した後のerror状態と、今度は検索結果1件を返す検索クライアント
        let repository = TestData.makeRepository(id: 1)
        var state = SearchFeature.State(favorites: Shared(value: []))
        state.searchQuery = "swift"
        state.searchError = "error"
        let store = TestStore(initialState: state) {
            SearchFeature()
        } withDependencies: {
            $0.searchClient.search = { _, _ in TestData.makeSearchResult(items: [repository]) }
            $0.favoriteClient.refresh = { [] }
            $0.searchHistoryClient.history = { [] }
            $0.searchHistoryClient.add = { [$0] }
        }

        // Act: タブ復帰で画面表示時の読み込みが再度走る
        await store.send(.view(.task))
        await store.receive(\.internal.loadResponse) {
            $0.isSearching = true
            $0.searchError = nil
            $0.lastSearchedQuery = "swift"
        }

        // Assert: スキップされず再検索され loaded 状態になる
        await store.receive(\.internal.searchResponse) {
            $0.items = [repository]
            $0.history = ["swift"]
            $0.isSearching = false
        }
        #expect(store.state.viewState == .loaded([RepositoryDisplayItem(repository: repository, isFavorite: false)]))
        await store.finish()
    }

    @Test("エラー画面の再試行で同じクエリを再検索する")
    func retryButtonSearchesAgain() async {
        // Arrange: "swift" の検索が失敗した後のerror状態と、今度は検索結果1件を返す検索クライアント
        let repository = TestData.makeRepository(id: 1)
        var state = SearchFeature.State(favorites: Shared(value: []))
        state.searchQuery = "swift"
        state.searchError = "error"
        let store = TestStore(initialState: state) {
            SearchFeature()
        } withDependencies: {
            $0.searchClient.search = { _, _ in TestData.makeSearchResult(items: [repository]) }
            $0.favoriteClient.refresh = { [] }
            $0.searchHistoryClient.add = { [$0] }
        }

        // Act: 再試行ボタンをタップ
        await store.send(.view(.retryButtonTapped)) {
            $0.isSearching = true
            $0.searchError = nil
            $0.lastSearchedQuery = "swift"
        }

        // Assert: 再検索され loaded 状態になる
        await store.receive(\.internal.searchResponse) {
            $0.items = [repository]
            $0.history = ["swift"]
            $0.isSearching = false
        }
        await store.finish()
    }

    // MARK: - お気に入り

    @Test("お気に入りトグルでisFavoriteがtrueになる")
    func favoriteButtonAddsFavorite() async {
        // Arrange: 検索結果1件（お気に入り未登録）のloaded状態と、追加されたリポジトリを記録するお気に入りクライアント
        let repository = TestData.makeRepository(id: 42)
        let favorite = TestData.makeFavorite(id: 42)
        let addedRepositories = LockIsolated<[RepositoryEntity]>([])
        var state = SearchFeature.State(favorites: Shared(value: []))
        state.searchQuery = "test"
        state.lastSearchedQuery = "test"
        state.items = [repository]
        let store = TestStore(initialState: state) {
            SearchFeature()
        } withDependencies: {
            $0.favoriteClient.add = { repository in
                addedRepositories.withValue { $0.append(repository) }
                return [favorite]
            }
        }

        // Act: ハートボタンをタップ
        await store.send(.view(.favoriteButtonTapped(id: 42)))

        // Assert: isFavoriteがtrueに変わり、対象のリポジトリで add が1回呼ばれる
        await store.receive(\.internal.favoritesResponse) {
            $0.$favorites.withLock { $0 = [favorite] }
        }
        #expect(store.state.viewState == .loaded([RepositoryDisplayItem(repository: repository, isFavorite: true)]))
        #expect(addedRepositories.value == [repository])
        await store.finish()
    }

    @Test("お気に入り解除でisFavoriteがfalseになる")
    func favoriteButtonRemovesFavorite() async {
        // Arrange: 検索結果1件（お気に入り済み）のloaded状態と、削除された ID を記録するお気に入りクライアント
        let repository = TestData.makeRepository(id: 42)
        let removedIDs = LockIsolated<[Int]>([])
        var state = SearchFeature.State(favorites: Shared(value: []))
        state.searchQuery = "test"
        state.lastSearchedQuery = "test"
        state.items = [repository]
        state.$favorites.withLock { $0 = [TestData.makeFavorite(id: 42)] }
        let store = TestStore(initialState: state) {
            SearchFeature()
        } withDependencies: {
            $0.favoriteClient.remove = { id in
                removedIDs.withValue { $0.append(id) }
                return []
            }
        }

        // Act: ハートボタンをタップ
        await store.send(.view(.favoriteButtonTapped(id: 42)))

        // Assert: isFavoriteがfalseに変わり、対象の ID で remove が1回呼ばれる
        await store.receive(\.internal.favoritesResponse) {
            $0.$favorites.withLock { $0 = [] }
        }
        #expect(store.state.viewState == .loaded([RepositoryDisplayItem(repository: repository, isFavorite: false)]))
        #expect(removedIDs.value == [42])
        await store.finish()
    }

    @Test("お気に入りタブ側での変更が、画面復帰時の読み込み後に検索結果の isFavorite へ反映される")
    func isFavoriteFollowsFavoriteChangesMadeElsewhere() async {
        // Arrange: 検索結果1件のloaded状態と、お気に入りタブ側の操作に見立てて返す一覧を差し替えられるお気に入りクライアント
        let repository = TestData.makeRepository(id: 42)
        let favorite = TestData.makeFavorite(id: 42)
        let favorites = LockIsolated<[FavoriteEntity]>([favorite])
        var state = SearchFeature.State(favorites: Shared(value: []))
        state.searchQuery = "test"
        state.lastSearchedQuery = "test"
        state.items = [repository]
        let store = TestStore(initialState: state) {
            SearchFeature()
        } withDependencies: {
            $0.favoriteClient.refresh = { favorites.value }
            $0.searchHistoryClient.history = { [] }
        }

        // Act: お気に入りタブで追加された後、検索タブへ戻って読み込みが走る
        await store.send(.view(.task))

        // Assert: 追加が isFavorite == true として反映される
        await store.receive(\.internal.loadResponse) {
            $0.$favorites.withLock { $0 = [favorite] }
        }
        #expect(store.state.viewState == .loaded([RepositoryDisplayItem(repository: repository, isFavorite: true)]))

        // Act: お気に入りタブで削除された後、再び読み込みが走る
        favorites.setValue([])
        await store.send(.view(.task))

        // Assert: 削除が isFavorite == false として反映される
        await store.receive(\.internal.loadResponse) {
            $0.$favorites.withLock { $0 = [] }
        }
        #expect(store.state.viewState == .loaded([RepositoryDisplayItem(repository: repository, isFavorite: false)]))
        await store.finish()
    }

    @Test("お気に入り追加失敗時にエラーアラートが表示される")
    func favoriteAddFailureShowsAlert() async {
        // Arrange: 検索結果1件のloaded状態と、追加に失敗するお気に入りクライアント
        var state = SearchFeature.State(favorites: Shared(value: []))
        state.searchQuery = "test"
        state.lastSearchedQuery = "test"
        state.items = [TestData.makeRepository(id: 42)]
        let store = TestStore(initialState: state) {
            SearchFeature()
        } withDependencies: {
            $0.favoriteClient.add = { _ in throw AppError.unknown("Mock error") }
        }

        // Act: ハートボタンをタップ（追加は失敗する）
        await store.send(.view(.favoriteButtonTapped(id: 42)))

        // Assert: エラーアラートが表示される
        await store.receive(\.internal.favoriteToggleFailed) {
            $0.destination = .alert(SearchFeature.favoriteUpdateFailedAlert)
        }
        await store.finish()
    }

    @Test("エラーアラートを閉じると表示状態がクリアされる")
    func dismissAlertClearsDestination() async {
        // Arrange: お気に入り更新失敗のアラートを表示中
        var state = SearchFeature.State(favorites: Shared(value: []))
        state.destination = .alert(SearchFeature.favoriteUpdateFailedAlert)
        let store = TestStore(initialState: state) {
            SearchFeature()
        }

        // Act: アラートを閉じる
        await store.send(.destination(.dismiss)) {
            // Assert: アラートの表示状態がクリアされる
            $0.destination = nil
        }
        await store.finish()
    }

    @Test("検索結果に存在しないIDのお気に入りトグルは何もしない")
    func favoriteButtonWithUnknownIDDoesNothing() async {
        // Arrange: 検索結果1件（id=1）のloaded状態（お気に入りクライアントは未設定＝呼ばれたらテスト失敗）
        var state = SearchFeature.State(favorites: Shared(value: []))
        state.searchQuery = "test"
        state.lastSearchedQuery = "test"
        state.items = [TestData.makeRepository(id: 1)]
        let store = TestStore(initialState: state) {
            SearchFeature()
        }

        // Act: 検索結果に存在しない ID でトグル
        await store.send(.view(.favoriteButtonTapped(id: 999)))

        // Assert: addもremoveも呼ばれず、状態も変わらない
        await store.finish()
    }

    // MARK: - ページネーション

    @Test("末尾の行が表示されると次ページが追加される")
    func rowAppearedAppendsNextPage() async {
        // Arrange: 次ページありの1ページ目を表示中。2ページ目の結果を返す検索クライアント（呼び出し引数を記録する）
        let page1Repository = TestData.makeRepository(id: 1, fullName: "page1/repo")
        let page2Repository = TestData.makeRepository(id: 2, fullName: "page2/repo")
        let searchCalls = LockIsolated<[SearchCall]>([])
        var state = SearchFeature.State(favorites: Shared(value: []))
        state.searchQuery = "test"
        state.lastSearchedQuery = "test"
        state.items = [page1Repository]
        state.hasNextPage = true
        let store = TestStore(initialState: state) {
            SearchFeature()
        } withDependencies: {
            $0.searchClient.search = { query, page in
                searchCalls.withValue { $0.append(SearchCall(query: query, page: page)) }
                return TestData.makeSearchResult(items: [page2Repository], hasNextPage: false)
            }
        }

        // Act: 末尾の行が表示される
        await store.send(.view(.rowAppeared(id: 1))) {
            $0.isLoadingMore = true
        }

        // Assert: 2ページ分のアイテムが並び、page=2 で検索されている
        await store.receive(\.internal.loadMoreResponse) {
            $0.isLoadingMore = false
            $0.currentPage = 2
            $0.items = [page1Repository, page2Repository]
            $0.hasNextPage = false
        }
        #expect(searchCalls.value == [SearchCall(query: "test", page: 2)])
        await store.finish()
    }

    @Test("ページ追加読み込み失敗時に既存データが維持される")
    func loadMoreFailureKeepsExistingData() async {
        // Arrange: 次ページありの1ページ目を表示中。2ページ目で通信エラーを投げる検索クライアント
        let repository = TestData.makeRepository(id: 1, fullName: "page1/repo")
        var state = SearchFeature.State(favorites: Shared(value: []))
        state.searchQuery = "test"
        state.lastSearchedQuery = "test"
        state.items = [repository]
        state.hasNextPage = true
        let store = TestStore(initialState: state) {
            SearchFeature()
        } withDependencies: {
            $0.searchClient.search = { _, _ in throw AppError.network }
        }

        // Act: 末尾の行が表示される（2ページ目の読み込みは失敗する）
        await store.send(.view(.rowAppeared(id: 1))) {
            $0.isLoadingMore = true
        }

        // Assert: 1ページ目のデータが維持され、isLoadingMoreもfalseに戻る
        await store.receive(\.internal.loadMoreFailed) {
            $0.isLoadingMore = false
        }
        #expect(store.state.viewState == .loaded([RepositoryDisplayItem(repository: repository, isFavorite: false)]))
        await store.finish()
    }

    @Test("次ページが無い場合は末尾の行が表示されても何もしない")
    func rowAppearedDoesNothingWhenNoNextPage() async {
        // Arrange: 次ページなしの検索結果を表示中（検索クライアントは未設定＝呼ばれたらテスト失敗）
        var state = SearchFeature.State(favorites: Shared(value: []))
        state.searchQuery = "test"
        state.lastSearchedQuery = "test"
        state.items = [TestData.makeRepository(id: 1)]
        state.hasNextPage = false
        let store = TestStore(initialState: state) {
            SearchFeature()
        }

        // Act: 末尾の行が表示される
        await store.send(.view(.rowAppeared(id: 1)))

        // Assert: 追加のAPI呼び出しが発生しない
        await store.finish()
    }

    @Test("ページ追加読み込み中に末尾の行が再度表示されてもAPIは1回しか呼ばれない")
    func rowAppearedPreventsDuplicateLoadMore() async {
        // Arrange: 次ページありの検索結果を表示中。テストが解放するまで完了しない検索クライアント（呼び出し回数を記録する）
        let repository = TestData.makeRepository(id: 1)
        let page2Repository = TestData.makeRepository(id: 2)
        let searchCallCount = LockIsolated(0)
        let (gate, gateContinuation) = AsyncStream.makeStream(of: Void.self)
        var state = SearchFeature.State(favorites: Shared(value: []))
        state.searchQuery = "test"
        state.lastSearchedQuery = "test"
        state.items = [repository]
        state.hasNextPage = true
        let store = TestStore(initialState: state) {
            SearchFeature()
        } withDependencies: {
            $0.searchClient.search = { _, _ in
                searchCallCount.withValue { $0 += 1 }
                for await _ in gate { break }
                return TestData.makeSearchResult(items: [page2Repository], hasNextPage: true)
            }
        }

        // Act: 末尾の行が表示され、読み込みが終わる前にもう一度表示される
        await store.send(.view(.rowAppeared(id: 1))) {
            $0.isLoadingMore = true
        }
        await store.send(.view(.rowAppeared(id: 1)))
        gateContinuation.yield()

        // Assert: 2回目は無視され、API 呼び出しは1回だけ
        await store.receive(\.internal.loadMoreResponse) {
            $0.isLoadingMore = false
            $0.currentPage = 2
            $0.items = [repository, page2Repository]
        }
        #expect(searchCallCount.value == 1)
        await store.finish()
    }

    // MARK: - スペースのみクエリ

    @Test("スペースのみのクエリはidleにリセットされる")
    func whitespaceOnlyQueryResetsToIdle() async {
        // Arrange: "swift" で検索済みのloaded状態
        var state = SearchFeature.State(favorites: Shared(value: []))
        state.searchQuery = "swift"
        state.lastSearchedQuery = "swift"
        state.items = [TestData.makeRepository(id: 1)]
        let store = TestStore(initialState: state) {
            SearchFeature()
        }

        // Act: スペースのみ入力
        await store.send(.view(.binding(.set(\.searchQuery, "   ")))) {
            $0.searchQuery = "   "
            $0.lastSearchedQuery = nil
            $0.items = []
        }

        // Assert: idle にリセット
        #expect(store.state.viewState == .idle)
        await store.finish()
    }

    // MARK: - リフレッシュ

    @Test("引っ張って更新で再検索が実行され結果が更新される")
    func refreshPulledReloadsData() async {
        // Arrange: "test" で検索済みのloaded状態（old/repo を表示中）と、新しい結果を返す検索クライアント
        let newRepository = TestData.makeRepository(id: 2, fullName: "new/repo")
        var state = SearchFeature.State(favorites: Shared(value: []))
        state.searchQuery = "test"
        state.lastSearchedQuery = "test"
        state.items = [TestData.makeRepository(id: 1, fullName: "old/repo")]
        let store = TestStore(initialState: state) {
            SearchFeature()
        } withDependencies: {
            $0.searchClient.search = { _, _ in TestData.makeSearchResult(items: [newRepository]) }
            $0.favoriteClient.refresh = { [] }
            $0.searchHistoryClient.add = { [$0] }
        }

        // Act: 引っ張って更新
        await store.send(.view(.refreshPulled)) {
            $0.isSearching = true
            $0.items = []
        }

        // Assert: 新しいデータに更新
        await store.receive(\.internal.searchResponse) {
            $0.items = [newRepository]
            $0.history = ["test"]
            $0.isSearching = false
        }
        #expect(store.state.viewState == .loaded([RepositoryDisplayItem(repository: newRepository, isFavorite: false)]))
        await store.finish()
    }

    // MARK: - リポジトリを開く

    @Test("行をタップすると GitHub ページを Safari シートで開く")
    func rowTappedPresentsSafari() async throws {
        // Arrange: owner/repo を1件表示中のloaded状態
        var state = SearchFeature.State(favorites: Shared(value: []))
        state.searchQuery = "test"
        state.lastSearchedQuery = "test"
        state.items = [TestData.makeRepository(id: 1, fullName: "owner/repo")]
        let store = TestStore(initialState: state) {
            SearchFeature()
        }
        let url = try #require(URL(string: "https://github.com/owner/repo"))

        // Act: 行をタップ
        await store.send(.view(.rowTapped(id: 1))) {
            // Assert: リポジトリの GitHub ページが Safari シートの表示対象になる
            $0.destination = .safari(SafariDestination(url: url))
        }
        await store.finish()
    }

    // MARK: - 検索履歴

    @Test("検索成功時に履歴へ追加される")
    func searchSuccessAddsToHistory() async {
        // Arrange: 検索結果1件を返す検索クライアントと、追加されたクエリを記録する履歴クライアント
        let repository = TestData.makeRepository(id: 1)
        let clock = TestClock()
        let addedQueries = LockIsolated<[String]>([])
        let store = TestStore(initialState: SearchFeature.State(favorites: Shared(value: []))) {
            SearchFeature()
        } withDependencies: {
            $0.continuousClock = clock
            $0.searchClient.search = { _, _ in TestData.makeSearchResult(items: [repository]) }
            $0.favoriteClient.refresh = { [] }
            $0.searchHistoryClient.add = { query in
                addedQueries.withValue { $0.append(query) }
                return [query]
            }
        }

        // Act: クエリを入力し、debounce の 500ms が経過する
        await store.send(.view(.binding(.set(\.searchQuery, "kotlin")))) {
            $0.searchQuery = "kotlin"
        }
        await clock.advance(by: .milliseconds(500))
        await store.receive(\.internal.debounceCompleted) {
            $0.isSearching = true
            $0.lastSearchedQuery = "kotlin"
        }

        // Assert: 履歴に "kotlin" が1回追加され、画面の履歴にも反映されている
        await store.receive(\.internal.searchResponse) {
            $0.items = [repository]
            $0.history = ["kotlin"]
            $0.isSearching = false
        }
        #expect(addedQueries.value == ["kotlin"])
        await store.finish()
    }

    @Test("履歴をタップすると即時検索が実行される（debounce バイパス）")
    func historyTappedSearchesImmediately() async {
        // Arrange: 履歴2件のidle状態と、検索結果1件を返す検索クライアント（clock は未設定＝待機したらテスト失敗）
        let repository = TestData.makeRepository(id: 1)
        var state = SearchFeature.State(favorites: Shared(value: []))
        state.history = ["swift", "kotlin"]
        let store = TestStore(initialState: state) {
            SearchFeature()
        } withDependencies: {
            $0.searchClient.search = { _, _ in TestData.makeSearchResult(items: [repository]) }
            $0.favoriteClient.refresh = { [] }
            $0.searchHistoryClient.add = { [$0, "swift"] }
        }

        // Act: 履歴から "kotlin" を選択
        await store.send(.view(.historyTapped("kotlin"))) {
            $0.searchQuery = "kotlin"
            $0.isSearching = true
            $0.lastSearchedQuery = "kotlin"
        }

        // Assert: クエリが反映され、待機なしで loaded 状態に遷移する
        await store.receive(\.internal.searchResponse) {
            $0.items = [repository]
            $0.history = ["kotlin", "swift"]
            $0.isSearching = false
        }
        await store.finish()
    }

    @Test("履歴の削除ボタンでその1件が履歴から削除される")
    func historyDeleteButtonRemovesEntry() async {
        // Arrange: 履歴3件のidle状態と、削除されたクエリを記録する履歴クライアント
        let removedQueries = LockIsolated<[String]>([])
        var state = SearchFeature.State(favorites: Shared(value: []))
        state.history = ["a", "b", "c"]
        let store = TestStore(initialState: state) {
            SearchFeature()
        } withDependencies: {
            $0.searchHistoryClient.remove = { query in
                removedQueries.withValue { $0.append(query) }
                return ["a", "c"]
            }
        }

        // Act: "b" の削除ボタンをタップ
        await store.send(.view(.historyDeleteButtonTapped("b")))

        // Assert: "b" で remove が1回呼ばれ、画面の履歴からも消える
        await store.receive(\.internal.historyResponse) {
            $0.history = ["a", "c"]
        }
        #expect(removedQueries.value == ["b"])
        await store.finish()
    }

    @Test("すべて消去で履歴が全消去される")
    func clearHistoryButtonClearsHistory() async {
        // Arrange: 履歴2件のidle状態と、全消去の呼び出し回数を記録する履歴クライアント
        let clearCallCount = LockIsolated(0)
        var state = SearchFeature.State(favorites: Shared(value: []))
        state.history = ["a", "b"]
        let store = TestStore(initialState: state) {
            SearchFeature()
        } withDependencies: {
            $0.searchHistoryClient.clear = { clearCallCount.withValue { $0 += 1 } }
        }

        // Act: 「すべて消去」をタップ
        await store.send(.view(.clearHistoryButtonTapped))

        // Assert: clear が1回呼ばれ、画面の履歴も空になる
        await store.receive(\.internal.historyResponse) {
            $0.history = []
        }
        #expect(clearCallCount.value == 1)
        await store.finish()
    }
}

/// 検索クライアントの呼び出し引数の記録
private struct SearchCall: Equatable {
    let query: String
    let page: Int
}
