/*
 Abstract:
 SwiftDataの in-memory ModelContainer を用いた
 FavoriteLocalDataSource の永続化動作検証テスト。
 */

import Foundation
import SwiftData
import Testing
import GitHubFinderDomain
@testable import GitHubFinderData

@Suite("FavoriteLocalDataSource")
struct FavoriteLocalDataSourceTests {

    @Test("空の時 getAll は空配列を返す")
    func getAllReturnsEmptyInitially() async throws {
        // Arrange: 空の in-memory DataSource を生成
        let dataSource = try makeDataSource()

        // Act: getAll を実行
        let all = try await dataSource.getAll()

        // Assert: 空配列が返る
        #expect(all.isEmpty)
    }

    @Test("add 後 getAll で取得できる")
    func addThenGetAll() async throws {
        // Arrange: 空の DataSource と RepositoryEntity を準備
        let dataSource = try makeDataSource()
        let entity = makeRepositoryEntity(id: 1, fullName: "owner/repo")

        // Act: add 後に getAll
        try await dataSource.add(entity)
        let all = try await dataSource.getAll()

        // Assert: 追加した1件が取得できる
        #expect(all.count == 1)
        #expect(all[0].id == 1)
        #expect(all[0].fullName == "owner/repo")
    }

    @Test("複数件は savedAt 降順で取得される")
    func getAllSortedBySavedAtDescending() async throws {
        // Arrange: savedAt を明示した3件を同じコンテナへ直接保存（時刻に依存せず順序を固定する）
        let container = try makeContainer()
        let context = ModelContext(container)
        for (id, offset) in [(1, 0.0), (2, 10.0), (3, 20.0)] {
            context.insert(FavoriteRecord(
                repositoryID: id,
                fullName: "owner/\(id)",
                descriptionText: nil,
                starCount: 0,
                language: nil,
                ownerAvatarURL: nil,
                savedAt: Date(timeIntervalSince1970: offset)
            ))
        }
        try context.save()
        let dataSource = FavoriteLocalDataSource(modelContainer: container)

        // Act: getAll を実行
        let all = try await dataSource.getAll()

        // Assert: savedAt が新しい順に並ぶ
        #expect(all.map(\.id) == [3, 2, 1])
    }

    @Test("remove で該当 ID が削除される")
    func removeDeletesEntry() async throws {
        // Arrange: id=1, id=2 を追加
        let dataSource = try makeDataSource()
        try await dataSource.add(makeRepositoryEntity(id: 1, fullName: "owner/a"))
        try await dataSource.add(makeRepositoryEntity(id: 2, fullName: "owner/b"))

        // Act: id=1 を削除
        try await dataSource.remove(id: 1)
        let all = try await dataSource.getAll()

        // Assert: id=2 だけ残る
        #expect(all.count == 1)
        #expect(all[0].id == 2)
    }

    @Test("存在しないIDの remove は例外を投げない")
    func removeNonExistentIsNoop() async throws {
        // Arrange: 空の DataSource
        let dataSource = try makeDataSource()

        // Act: 存在しない ID を remove（例外が発生しないこと）
        try await dataSource.remove(id: 999)
        let all = try await dataSource.getAll()

        // Assert: 副作用なく空のまま
        #expect(all.isEmpty)
    }
}

// MARK: - Helpers

extension FavoriteLocalDataSourceTests {
    fileprivate func makeContainer() throws -> ModelContainer {
        let schema = Schema([FavoriteRecord.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: config)
    }

    fileprivate func makeDataSource() throws -> FavoriteLocalDataSource {
        FavoriteLocalDataSource(modelContainer: try makeContainer())
    }

    fileprivate func makeRepositoryEntity(
        id: Int,
        fullName: String,
    ) -> RepositoryEntity {
        RepositoryEntity(
            id: id,
            fullName: fullName,
            description: nil,
            starCount: 0,
            language: nil,
            ownerAvatarURL: nil
        )
    }
}
