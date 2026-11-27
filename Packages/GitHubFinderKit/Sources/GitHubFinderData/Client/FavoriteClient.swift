/*
 Abstract:
 お気に入りの読み込み・追加・削除を Reducer へ公開する依存クライアント。
 本番実装は FavoriteStore の薄いラッパー（FavoriteClient+Live.swift）。
 どの操作も、操作後の最新のお気に入り一覧を返す。Reducer はそれを自分の State に保存する。
 */

import Dependencies
import DependenciesMacros
import GitHubFinderDomain

@DependencyClient
public struct FavoriteClient: Sendable {
    /// お気に入りを読み直して最新の一覧を返す。読み込みに失敗したときは直前の一覧を返す
    public var refresh: @Sendable () async -> [FavoriteEntity] = { [] }
    /// お気に入りに追加し、追加後の一覧を返す
    public var add: @Sendable (_ repository: RepositoryEntity) async throws -> [FavoriteEntity]
    /// お気に入りから削除し、削除後の一覧を返す
    public var remove: @Sendable (_ id: Int) async throws -> [FavoriteEntity]
}

extension FavoriteClient: TestDependencyKey {
    public static let testValue = FavoriteClient()
}

extension DependencyValues {
    public var favoriteClient: FavoriteClient {
        get { self[FavoriteClient.self] }
        set { self[FavoriteClient.self] = newValue }
    }
}
