/*
 Abstract:
 お気に入りのデータアクセス契約。
 */

public protocol FavoriteRepositoryProtocol: Sendable {
    func getAll() async throws -> [FavoriteEntity]
    func add(_ repository: RepositoryEntity) async throws
    func remove(id: Int) async throws
}
