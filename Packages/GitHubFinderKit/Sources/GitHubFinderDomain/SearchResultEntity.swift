/*
 Abstract:
 検索結果を表すドメインエンティティ。ページネーション情報を含む。
 */

public struct SearchResultEntity: Equatable, Sendable {
    public let totalCount: Int
    public let items: [RepositoryEntity]
    public let hasNextPage: Bool

    public init(totalCount: Int, items: [RepositoryEntity], hasNextPage: Bool) {
        self.totalCount = totalCount
        self.items = items
        self.hasNextPage = hasNextPage
    }
}
