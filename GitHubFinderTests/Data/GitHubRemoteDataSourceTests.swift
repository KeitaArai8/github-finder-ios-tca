/*
 Abstract:
 MockURLProtocolForRemoteを利用したGitHubRemoteDataSourceのAPI統合テスト。
 レスポンスのパース・HTTPステータスコードのエラーマッピングを検証する。
 */

import Foundation
import Testing
import GitHubFinderDomain
@testable import GitHubFinderData

@Suite("GitHubRemoteDataSource", .serialized)
struct GitHubRemoteDataSourceTests {

    @Test("200応答で正しくDTOにデコードされる")
    func successfulResponseParsesDTO() async throws {
        // Arrange: 有効なJSONを返すモック + DataSource を準備
        MockURLProtocolForRemote.reset()
        let json = """
        {
          "total_count": 2,
          "items": [
            {
              "id": 1,
              "full_name": "owner/repo",
              "description": "sample",
              "stargazers_count": 100,
              "language": "Swift",
              "owner": { "avatar_url": "https://example.com/a.png" }
            }
          ]
        }
        """.data(using: .utf8)!
        MockURLProtocolForRemote.requestHandler = { request in
            (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, json)
        }
        let dataSource = GitHubRemoteDataSource(session: MockURLProtocolForRemote.makeURLSession())

        // Act: 検索を実行
        let dto = try await dataSource.searchRepositories(query: "swift", page: 1)

        // Assert: DTO フィールドが正しくマップされている
        #expect(dto.totalCount == 2)
        #expect(dto.items.count == 1)
        #expect(dto.items[0].fullName == "owner/repo")
    }

    @Test("クエリパラメータがURLに含まれる")
    func queryParametersAreBuiltCorrectly() async throws {
        // Arrange: リクエストをキャプチャするモック
        MockURLProtocolForRemote.reset()
        MockURLProtocolForRemote.requestHandler = { request in
            let json = #"{"total_count":0,"items":[]}"#.data(using: .utf8)!
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, json)
        }
        let dataSource = GitHubRemoteDataSource(session: MockURLProtocolForRemote.makeURLSession())

        // Act: query="swift", page=3 で検索
        _ = try await dataSource.searchRepositories(query: "swift", page: 3)

        // Assert: q / page / per_page が URL に正しく含まれる
        let url = try #require(MockURLProtocolForRemote.lastRequest?.url)
        let components = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
        let queryItems = components.queryItems ?? []
        #expect(queryItems.contains(URLQueryItem(name: "q", value: "swift")))
        #expect(queryItems.contains(URLQueryItem(name: "page", value: "3")))
        #expect(queryItems.contains(URLQueryItem(name: "per_page", value: "30")))
    }

    @Test("403応答でAppError.rateLimitが投げられる")
    func rateLimitErrorMapping() async {
        // Arrange: 403 を返すモック
        MockURLProtocolForRemote.reset()
        MockURLProtocolForRemote.requestHandler = { request in
            (HTTPURLResponse(url: request.url!, statusCode: 403, httpVersion: nil, headerFields: nil)!, Data())
        }
        let dataSource = GitHubRemoteDataSource(session: MockURLProtocolForRemote.makeURLSession())

        // Act & Assert: AppError.rateLimit が投げられる
        await #expect(throws: AppError.rateLimit) {
            _ = try await dataSource.searchRepositories(query: "swift", page: 1)
        }
    }

    @Test("4xx と 5xx の応答でステータスコード付きの AppError.server が投げられる", arguments: [500, 404])
    func serverErrorMapping(statusCode: Int) async {
        // Arrange: 指定のステータスコードを返すモック
        MockURLProtocolForRemote.reset()
        MockURLProtocolForRemote.requestHandler = { request in
            (HTTPURLResponse(url: request.url!, statusCode: statusCode, httpVersion: nil, headerFields: nil)!, Data())
        }
        let dataSource = GitHubRemoteDataSource(session: MockURLProtocolForRemote.makeURLSession())

        // Act: 検索を試行
        do {
            _ = try await dataSource.searchRepositories(query: "swift", page: 1)
            Issue.record("Expected AppError.server")
        } catch let error as AppError {
            // Assert: 返したステータスコードを持つ AppError.server が投げられる
            if case .server(let code) = error {
                #expect(code == statusCode)
            } else {
                Issue.record("Expected .server, got \(error)")
            }
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }
    }

    @Test("不正JSONでDecodingErrorが投げられる")
    func invalidJSONThrowsDecodingError() async {
        // Arrange: 200 だが JSON として不正なボディを返すモック
        MockURLProtocolForRemote.reset()
        MockURLProtocolForRemote.requestHandler = { request in
            let invalid = "not json".data(using: .utf8)!
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, invalid)
        }
        let dataSource = GitHubRemoteDataSource(session: MockURLProtocolForRemote.makeURLSession())

        // Act & Assert: 何らかのエラーが投げられる（DecodingError は Repository 層で AppError.decode にマップされる）
        await #expect(throws: (any Error).self) {
            _ = try await dataSource.searchRepositories(query: "swift", page: 1)
        }
    }
}
