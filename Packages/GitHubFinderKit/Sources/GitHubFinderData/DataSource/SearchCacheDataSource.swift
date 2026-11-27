/*
 Abstract:
 検索結果のメモリキャッシュを管理するデータソース。
 */

import GitHubFinderDomain

public actor SearchCacheDataSource {
    private var cache: [String: SearchResultEntity] = [:]

    public init() {}

    public func get(query: String, page: Int) -> SearchResultEntity? {
        cache[cacheKey(query: query, page: page)]
    }

    public func set(query: String, page: Int, result: SearchResultEntity) {
        cache[cacheKey(query: query, page: page)] = result
    }

    private func cacheKey(query: String, page: Int) -> String {
        "\(query.lowercased()):\(page)"
    }
}
