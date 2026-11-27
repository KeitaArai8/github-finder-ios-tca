/*
 Abstract:
 FavoriteStore の読み込み失敗時の振る舞いをテストする。
 */

import Testing
import GitHubFinderDomain
@testable import GitHubFinderData

@Suite("FavoriteStore")
@MainActor
struct FavoriteStoreTests {

    @Test("読み込み失敗時は例外を吸収し、直前の一覧（未読み込みなら空）を維持する")
    func refreshFailureKeepsPreviousFavorites() async {
        // Arrange: getAll が失敗するリポジトリを持つ、未読み込みの FavoriteStore
        let repository = MockFavoriteRepository()
        repository.shouldThrowOnGetAll = true
        let store = FavoriteStore(favoriteRepository: repository)

        // Act: 読み直す（失敗する）
        await store.refresh()

        // Assert: 例外は外へ出ず、一覧は空のまま（お気に入り画面では empty 状態になる）
        #expect(store.favorites.isEmpty)
        #expect(store.favoriteIDs.isEmpty)
    }
}
