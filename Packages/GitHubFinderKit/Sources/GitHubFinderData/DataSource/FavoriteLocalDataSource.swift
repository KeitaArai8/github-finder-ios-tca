/*
 Abstract:
 SwiftDataを使用したお気に入りのローカル永続化を担当するデータソース。
 */

import Foundation
import SwiftData
import GitHubFinderDomain

/// `@ModelActor` が `init(modelContainer:)` と actor 専用の `modelContext` を生成する。
/// メソッドごとに ModelContext を作らず、actor に紐づく 1 つの context を使い回す。
@ModelActor
public actor FavoriteLocalDataSource {
    public func getAll() async throws -> [FavoriteEntity] {
        let descriptor = FetchDescriptor<FavoriteRecord>(
            sortBy: [SortDescriptor(\.savedAt, order: .reverse)]
        )
        let models = try modelContext.fetch(descriptor)
        return models.map { $0.toEntity() }
    }

    public func add(_ repository: RepositoryEntity) async throws {
        let model = FavoriteRecord(repository: repository)
        modelContext.insert(model)
        try modelContext.save()
    }

    public func remove(id: Int) async throws {
        let descriptor = FetchDescriptor<FavoriteRecord>(
            predicate: #Predicate { $0.repositoryID == id }
        )
        let models = try modelContext.fetch(descriptor)
        for model in models {
            modelContext.delete(model)
        }
        try modelContext.save()
    }
}
