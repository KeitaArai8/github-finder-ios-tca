/*
 Abstract:
 お気に入り状態を一元管理する共有ストア。SearchModel と FavoriteModel の両方がこのストアを参照する。
 NiA の `:core:data` における `FavoriteStore` 同等の役割。
 */

import Foundation
import WidgetKit
import GitHubFinderDomain

@Observable
@MainActor
public final class FavoriteStore {
    public private(set) var favoriteIDs: Set<Int> = []
    public private(set) var favorites: [FavoriteEntity] = []

    private let favoriteRepository: FavoriteRepositoryProtocol

    public init(favoriteRepository: FavoriteRepositoryProtocol) {
        self.favoriteRepository = favoriteRepository
    }

    public func refresh() async {
        do {
            favorites = try await favoriteRepository.getAll()
            favoriteIDs = Set(favorites.map(\.id))
        } catch {
            // リフレッシュ失敗時は現在の状態を維持
        }
    }

    public func add(_ repository: RepositoryEntity) async throws {
        try await favoriteRepository.add(repository)
        await refresh()
        reloadWidgetTimelines()
    }

    public func remove(id: Int) async throws {
        try await favoriteRepository.remove(id: id)
        await refresh()
        reloadWidgetTimelines()
    }

    public func contains(id: Int) -> Bool {
        favoriteIDs.contains(id)
    }

    /// お気に入りの変更をウィジェットへ即時反映する（次回の定期更新を待たない）
    private func reloadWidgetTimelines() {
        WidgetCenter.shared.reloadTimelines(ofKind: AppGroupContainer.favoriteWidgetKind)
    }
}
