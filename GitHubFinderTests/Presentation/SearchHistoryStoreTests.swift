/*
 Abstract:
 SearchHistoryStore の永続化・重複排除・上限管理ロジックを検証する。
 各テストは独立した UserDefaults Suite を使い、互いに干渉しない。
 */

import Foundation
import Testing
@testable import GitHubFinderData

@Suite("SearchHistoryStore")
@MainActor
struct SearchHistoryStoreTests {

    @Test("追加すると先頭に挿入される")
    func addInsertsAtFront() {
        // Arrange: 空の履歴 Store
        let store = SearchHistoryStoreTests.makeStore()

        // Act:
        store.add("swift")
        store.add("compose")

        // Assert: 後に追加した方が先頭
        #expect(store.history == ["compose", "swift"])
    }

    @Test("空白のみのクエリは無視される")
    func addIgnoresWhitespaceOnly() {
        // Arrange:
        let store = SearchHistoryStoreTests.makeStore()

        // Act:
        store.add("   ")
        store.add("\n\t")
        store.add("")

        // Assert: 何も追加されない
        #expect(store.history.isEmpty)
    }

    @Test("先頭の空白がトリムされる")
    func addTrimsLeadingWhitespace() {
        // Arrange:
        let store = SearchHistoryStoreTests.makeStore()

        // Act:
        store.add("  swift  ")

        // Assert: トリム後の値で保存
        #expect(store.history == ["swift"])
    }

    @Test("同じクエリを再追加すると重複排除して先頭に再配置される")
    func addDeduplicatesAndMovesToFront() {
        // Arrange:
        let store = SearchHistoryStoreTests.makeStore()
        store.add("swift")
        store.add("compose")
        store.add("kotlin")

        // Act: 末尾の swift を再追加
        store.add("swift")

        // Assert: 重複なしで先頭に
        #expect(store.history == ["swift", "kotlin", "compose"])
    }

    @Test("maxEntries を超えると古い順に切り詰められる")
    func addRespectsMaxEntries() {
        // Arrange: maxEntries=3 の Store
        let store = SearchHistoryStoreTests.makeStore(maxEntries: 3)

        // Act: 4 件追加
        store.add("a")
        store.add("b")
        store.add("c")
        store.add("d")

        // Assert: 最新の 3 件のみ残る（"a" は切り捨て）
        #expect(store.history == ["d", "c", "b"])
    }

    @Test("remove で単一エントリが削除される")
    func removeDeletesSingleEntry() {
        // Arrange:
        let store = SearchHistoryStoreTests.makeStore()
        store.add("swift")
        store.add("compose")
        store.add("kotlin")

        // Act:
        store.remove("compose")

        // Assert: 中間の compose のみ削除
        #expect(store.history == ["kotlin", "swift"])
    }

    @Test("clear で履歴が全消去される")
    func clearRemovesAllEntries() {
        // Arrange:
        let store = SearchHistoryStoreTests.makeStore()
        store.add("a")
        store.add("b")

        // Act:
        store.clear()

        // Assert:
        #expect(store.history.isEmpty)
    }

    @Test("UserDefaults への永続化と再起動時のロードが機能する")
    func persistsAcrossInstances() {
        // Arrange: 同じ Suite/Key を共有する 2 つのインスタンス
        let suite = "test.\(UUID().uuidString)"
        let userDefaults = UserDefaults(suiteName: suite)!
        let key = "history"
        let store1 = SearchHistoryStore(userDefaults: userDefaults, storageKey: key, maxEntries: 10)
        store1.add("first")
        store1.add("second")

        // Act: 別インスタンスを作成（= 再起動シミュレーション）
        let store2 = SearchHistoryStore(userDefaults: userDefaults, storageKey: key, maxEntries: 10)

        // Assert: 永続化された履歴が読み込まれる
        #expect(store2.history == ["second", "first"])
    }
}

// MARK: - Helper

extension SearchHistoryStoreTests {
    /// 各テストで独立した UserDefaults Suite を使い、テスト間の干渉を防ぐ
    fileprivate static func makeStore(maxEntries: Int = 10) -> SearchHistoryStore {
        let suite = "test.\(UUID().uuidString)"
        let userDefaults = UserDefaults(suiteName: suite) ?? .standard
        return SearchHistoryStore(
            userDefaults: userDefaults,
            storageKey: "history",
            maxEntries: maxEntries
        )
    }
}
