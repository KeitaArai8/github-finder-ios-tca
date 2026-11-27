/*
 Abstract:
 リポジトリ検索のデータアクセス契約。
 */

public protocol SearchRepositoryProtocol: Sendable {
    func search(query: String, page: Int) async throws -> SearchResultEntity
}
