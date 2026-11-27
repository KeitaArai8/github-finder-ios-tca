/*
 Abstract:
 ローカルデータソースを使用するお気に入りリポジトリの実装。
 */

import Foundation
import GitHubFinderDomain

public final class FavoriteRepositoryImpl: FavoriteRepositoryProtocol, Sendable {
    private let localDataSource: FavoriteLocalDataSource

    public init(localDataSource: FavoriteLocalDataSource) {
        self.localDataSource = localDataSource
    }

    public func getAll() async throws -> [FavoriteEntity] {
        try await localDataSource.getAll()
    }

    public func add(_ repository: RepositoryEntity) async throws {
        try await localDataSource.add(repository)
    }

    public func remove(id: Int) async throws {
        try await localDataSource.remove(id: id)
    }
}
