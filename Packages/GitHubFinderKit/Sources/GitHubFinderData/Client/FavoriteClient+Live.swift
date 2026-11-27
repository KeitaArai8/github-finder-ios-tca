/*
 Abstract:
 FavoriteClient の本番実装。App Group の SwiftData を読む FavoriteStore を 1 つだけ作り、全画面で共有する。
 */

import Dependencies
import SwiftData
import GitHubFinderDomain

extension FavoriteClient: DependencyKey {
    public static let liveValue = FavoriteClient(
        refresh: { @MainActor in
            await LiveFavoriteStore.shared.refresh()
            return LiveFavoriteStore.shared.favorites
        },
        add: { @MainActor repository in
            try await LiveFavoriteStore.shared.add(repository)
            return LiveFavoriteStore.shared.favorites
        },
        remove: { @MainActor id in
            try await LiveFavoriteStore.shared.remove(id: id)
            return LiveFavoriteStore.shared.favorites
        }
    )
}

@MainActor
private enum LiveFavoriteStore {
    static let shared: FavoriteStore = {
        // App Group エンタイトルメントの未設定は開発時のみ発生するため、ここは致命エラーとして扱う
        let container: ModelContainer
        do {
            container = try AppGroupContainer.makeModelContainer()
        } catch {
            fatalError("Failed to create App Group ModelContainer. Check entitlements for \(AppGroupContainer.identifier): \(error)")
        }
        return FavoriteStore(
            favoriteRepository: FavoriteRepositoryImpl(
                localDataSource: FavoriteLocalDataSource(modelContainer: container)
            )
        )
    }()
}
