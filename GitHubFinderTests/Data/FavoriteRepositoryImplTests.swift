/*
 Abstract:
 SwiftDataのin-memoryコンテナを用いた
 FavoriteRepositoryImpl の委譲・永続化の統合テスト。
 */

import Foundation
import SwiftData
import Testing
import GitHubFinderDomain
@testable import GitHubFinderData

@Suite("FavoriteRepositoryImpl")
struct FavoriteRepositoryImplTests {

    @Test("add 後に getAll で取得できる")
    func addThenGetAll() async throws {
        // Arrange: in-memory SwiftData Repository を生成
        let repository = try makeRepository()

        // Act: id=1 を add 後に getAll
        try await repository.add(makeRepositoryEntity(id: 1))
        let all = try await repository.getAll()

        // Assert: 追加した1件が取得できる
        #expect(all.count == 1)
        #expect(all[0].id == 1)
    }

    @Test("remove で削除される")
    func removeDeletesEntry() async throws {
        // Arrange: 2件追加済みの Repository
        let repository = try makeRepository()
        try await repository.add(makeRepositoryEntity(id: 1))
        try await repository.add(makeRepositoryEntity(id: 2))

        // Act: id=1 を削除
        try await repository.remove(id: 1)
        let all = try await repository.getAll()

        // Assert: id=2 だけ残る
        #expect(all.count == 1)
        #expect(all[0].id == 2)
    }
}

// MARK: - Helpers

extension FavoriteRepositoryImplTests {
    fileprivate func makeRepository() throws -> FavoriteRepositoryImpl {
        let schema = Schema([FavoriteRecord.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: config)
        return FavoriteRepositoryImpl(
            localDataSource: FavoriteLocalDataSource(modelContainer: container)
        )
    }

    fileprivate func makeRepositoryEntity(id: Int) -> RepositoryEntity {
        RepositoryEntity(
            id: id,
            fullName: "owner/repo\(id)",
            description: nil,
            starCount: 0,
            language: nil,
            ownerAvatarURL: nil
        )
    }
}
