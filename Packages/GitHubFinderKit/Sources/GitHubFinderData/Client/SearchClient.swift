/*
 Abstract:
 リポジトリ検索を Reducer へ公開する依存クライアント。
 本番実装は SearchRepositoryImpl（リモート取得 + キャッシュ）の薄いラッパー。
 */

import Dependencies
import DependenciesMacros
import GitHubFinderDomain

@DependencyClient
public struct SearchClient: Sendable {
    public var search: @Sendable (_ query: String, _ page: Int) async throws -> SearchResultEntity
}

extension SearchClient: DependencyKey {
    public static let liveValue: SearchClient = {
        let repository = SearchRepositoryImpl(
            remoteDataSource: GitHubRemoteDataSource(),
            cacheDataSource: SearchCacheDataSource()
        )
        return SearchClient(
            search: { query, page in
                try await repository.search(query: query, page: page)
            }
        )
    }()

    public static let testValue = SearchClient()
}

extension DependencyValues {
    public var searchClient: SearchClient {
        get { self[SearchClient.self] }
        set { self[SearchClient.self] = newValue }
    }
}
