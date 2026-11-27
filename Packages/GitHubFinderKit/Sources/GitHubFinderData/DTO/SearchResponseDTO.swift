/*
 Abstract:
 GitHub API の検索レスポンスをデコードするためのDTO。Data target 内部実装のため非 public。
 */

struct SearchResponseDTO: Decodable, Sendable {
    let totalCount: Int
    let items: [RepositoryDTO]
}
