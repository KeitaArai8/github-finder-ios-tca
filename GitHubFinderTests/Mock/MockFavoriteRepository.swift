/*
 Abstract:
 テスト用のお気に入りリポジトリモック。
 */

import Foundation
import GitHubFinderDomain

final class MockFavoriteRepository: FavoriteRepositoryProtocol, @unchecked Sendable {
    var favorites: [FavoriteEntity] = []
    var favoriteIDs: Set<Int> = []
    var addCallCount = 0
    var removeCallCount = 0
    var lastAddedRepository: RepositoryEntity?
    var lastRemovedID: Int?
    var shouldThrowOnAdd = false
    var shouldThrowOnRemove = false
    var shouldThrowOnGetAll = false
    var getAllError: Error?

    func getAll() async throws -> [FavoriteEntity] {
        if let error = getAllError { throw error }
        if shouldThrowOnGetAll { throw AppError.unknown("Mock error") }
        return favorites
    }

    func add(_ repository: RepositoryEntity) async throws {
        if shouldThrowOnAdd { throw AppError.unknown("Mock error") }
        addCallCount += 1
        lastAddedRepository = repository
        favoriteIDs.insert(repository.id)
        favorites.append(FavoriteEntity(
            id: repository.id,
            fullName: repository.fullName,
            description: repository.description,
            starCount: repository.starCount,
            language: repository.language,
            ownerAvatarURL: repository.ownerAvatarURL,
            savedAt: Date()
        ))
    }

    func remove(id: Int) async throws {
        if shouldThrowOnRemove { throw AppError.unknown("Mock error") }
        removeCallCount += 1
        lastRemovedID = id
        favoriteIDs.remove(id)
        favorites.removeAll { $0.id == id }
    }
}
