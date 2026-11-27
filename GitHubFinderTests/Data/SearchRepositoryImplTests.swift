/*
 Abstract:
 SearchRepositoryImplのキャッシュ統合・エラーマッピングを検証する統合テスト。
 Remote層はURLProtocolでモック、Cache層は実インスタンスを使用する。
 */

import Foundation
import Testing
import GitHubFinderDomain
@testable import GitHubFinderData

@Suite("SearchRepositoryImpl", .serialized)
struct SearchRepositoryImplTests {

    @Test("初回検索はリモートAPIを呼ぶ")
    func initialSearchHitsRemote() async throws {
        // Arrange: 正常応答を返すモック + Repository を準備
        MockURLProtocolForRepository.reset()
        setupSuccessfulJSON(totalCount: 1)
        let repository = makeRepository()

        // Act: 初回検索を実行
        _ = try await repository.search(query: "swift", page: 1)

        // Assert: Remote が1回呼ばれる
        #expect(MockURLProtocolForRepository.callCount == 1)
    }

    @Test("同一クエリかつ同一ページの再検索はキャッシュヒットしリモートを呼ばない")
    func secondSearchWithSameQueryHitsCache() async throws {
        // Arrange: 正常応答を返すモック
        MockURLProtocolForRepository.reset()
        setupSuccessfulJSON(totalCount: 1)
        let repository = makeRepository()

        // Act: 同じクエリ/ページで2回検索
        _ = try await repository.search(query: "swift", page: 1)
        _ = try await repository.search(query: "swift", page: 1)

        // Assert: Remote は1回しか呼ばれない（キャッシュヒット）
        #expect(MockURLProtocolForRepository.callCount == 1)
    }

    @Test("異なるページの検索はキャッシュミスしリモートを呼ぶ")
    func differentPageHitsRemote() async throws {
        // Arrange: hasNextPage=true 相当の応答
        MockURLProtocolForRepository.reset()
        setupSuccessfulJSON(totalCount: 60)
        let repository = makeRepository()

        // Act: page=1 と page=2 を検索
        _ = try await repository.search(query: "swift", page: 1)
        _ = try await repository.search(query: "swift", page: 2)

        // Assert: Remote は2回呼ばれる
        #expect(MockURLProtocolForRepository.callCount == 2)
    }

    @Test(
        "totalCount と page * 30 の大小に応じて hasNextPage が決まる",
        arguments: [(totalCount: 100, expected: true), (totalCount: 20, expected: false)]
    )
    func hasNextPageReflectsRemainingResults(totalCount: Int, expected: Bool) async throws {
        // Arrange: page=1 の時点で残りがある(100件) / 全件収まる(20件) 応答
        MockURLProtocolForRepository.reset()
        setupSuccessfulJSON(totalCount: totalCount)
        let repository = makeRepository()

        // Act: page=1 で検索
        let result = try await repository.search(query: "swift", page: 1)

        // Assert: totalCount > page * 30 のときだけ hasNextPage が true
        #expect(result.hasNextPage == expected)
    }

    @Test("AppError.rateLimit は透過する")
    func rateLimitErrorPassesThrough() async {
        // Arrange: 403 を返すモック
        MockURLProtocolForRepository.reset()
        MockURLProtocolForRepository.requestHandler = { request in
            (HTTPURLResponse(url: request.url!, statusCode: 403, httpVersion: nil, headerFields: nil)!, Data())
        }
        let repository = makeRepository()

        // Act & Assert: AppError.rateLimit がそのまま透過
        await #expect(throws: AppError.rateLimit) {
            _ = try await repository.search(query: "swift", page: 1)
        }
    }

    @Test("URLError は AppError.network にマップされる")
    func urlErrorMapsToNetwork() async {
        // Arrange: URLError(.notConnectedToInternet) を投げるモック
        MockURLProtocolForRepository.reset()
        MockURLProtocolForRepository.requestHandler = { _ in
            throw URLError(.notConnectedToInternet)
        }
        let repository = makeRepository()

        // Act & Assert: AppError.network にマップされる
        await #expect(throws: AppError.network) {
            _ = try await repository.search(query: "swift", page: 1)
        }
    }

    @Test("URLError(.cancelled) は AppError.network ではなく CancellationError になる")
    func cancelledURLErrorMapsToCancellation() async {
        // Arrange: URLError(.cancelled) を投げるモック（`.task(id:)` のキャンセル時に URLSession が投げるエラー）
        MockURLProtocolForRepository.reset()
        MockURLProtocolForRepository.requestHandler = { _ in
            throw URLError(.cancelled)
        }
        let repository = makeRepository()

        // Act & Assert: CancellationError として伝播する
        await #expect(throws: CancellationError.self) {
            _ = try await repository.search(query: "swift", page: 1)
        }
    }

    @Test("不正JSONは AppError.decode にマップされる")
    func decodingErrorMapsToDecode() async {
        // Arrange: 200 だが不正な JSON を返すモック
        MockURLProtocolForRepository.reset()
        MockURLProtocolForRepository.requestHandler = { request in
            let invalid = "not json".data(using: .utf8)!
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, invalid)
        }
        let repository = makeRepository()

        // Act & Assert: AppError.decode にマップされる
        await #expect(throws: AppError.decode) {
            _ = try await repository.search(query: "swift", page: 1)
        }
    }
}

// MARK: - Helpers

extension SearchRepositoryImplTests {
    fileprivate func makeRepository() -> SearchRepositoryImpl {
        SearchRepositoryImpl(
            remoteDataSource: GitHubRemoteDataSource(session: MockURLProtocolForRepository.makeURLSession()),
            cacheDataSource: SearchCacheDataSource()
        )
    }

    fileprivate func setupSuccessfulJSON(totalCount: Int) {
        let json = """
        {
          "total_count": \(totalCount),
          "items": [
            {
              "id": 1,
              "full_name": "owner/repo",
              "description": null,
              "stargazers_count": 0,
              "language": null,
              "owner": { "avatar_url": "https://example.com/a.png" }
            }
          ]
        }
        """.data(using: .utf8)!
        MockURLProtocolForRepository.requestHandler = { request in
            (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, json)
        }
    }
}
