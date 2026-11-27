/*
 Abstract:
 SearchCacheDataSourceのメモリキャッシュ動作を検証する単体テスト。
 */

import Testing
import GitHubFinderDomain
@testable import GitHubFinderData

@Suite("SearchCacheDataSource")
struct SearchCacheDataSourceTests {

    @Test("未保存のクエリとページの組は nil を返す")
    func getReturnsNilForUnsavedKey() async {
        // Arrange: 空のキャッシュを生成
        let cache = SearchCacheDataSource()

        // Act: 未保存のキーで取得
        let result = await cache.get(query: "swift", page: 1)

        // Assert: nil が返る
        #expect(result == nil)
    }

    @Test("set 後の get は保存した値を返す")
    func getReturnsSavedValue() async {
        // Arrange: totalCount=10, items=5件の結果をキャッシュに保存
        let cache = SearchCacheDataSource()
        let expected = makeResult(totalCount: 10, itemCount: 5)
        await cache.set(query: "swift", page: 1, result: expected)

        // Act: 同じキーで取得
        let actual = await cache.get(query: "swift", page: 1)

        // Assert: 保存した値が返る
        #expect(actual?.totalCount == expected.totalCount)
        #expect(actual?.items.count == expected.items.count)
    }

    @Test("異なるページは別キーで管理される")
    func differentPagesAreStoredSeparately() async {
        // Arrange: page1 と page2 をそれぞれ保存
        let cache = SearchCacheDataSource()
        let page1 = makeResult(totalCount: 60, itemCount: 30)
        let page2 = makeResult(totalCount: 60, itemCount: 30)
        await cache.set(query: "swift", page: 1, result: page1)
        await cache.set(query: "swift", page: 2, result: page2)

        // Act & Assert: 各ページが独立して取得できる
        #expect(await cache.get(query: "swift", page: 1)?.items.count == 30)
        #expect(await cache.get(query: "swift", page: 2)?.items.count == 30)
    }

    @Test("クエリは大文字小文字を区別しない")
    func queryIsCaseInsensitive() async {
        // Arrange: "Swift"（大文字始まり）で保存
        let cache = SearchCacheDataSource()
        let result = makeResult(totalCount: 1, itemCount: 1)
        await cache.set(query: "Swift", page: 1, result: result)

        // Act & Assert: "swift"（小文字）/ "SWIFT"（全大文字）でも取得可能
        #expect(await cache.get(query: "swift", page: 1) != nil)
        #expect(await cache.get(query: "SWIFT", page: 1) != nil)
    }
}

// MARK: - Helper

extension SearchCacheDataSourceTests {
    fileprivate func makeResult(totalCount: Int, itemCount: Int) -> SearchResultEntity {
        let items = (0..<itemCount).map { index in
            RepositoryEntity(
                id: index,
                fullName: "owner/repo\(index)",
                description: nil,
                starCount: 0,
                language: nil,
                ownerAvatarURL: nil
            )
        }
        return SearchResultEntity(totalCount: totalCount, items: items, hasNextPage: false)
    }
}
