/*
 Abstract:
 お気に入りストアのスキーマバージョンとマイグレーション計画。
 モデル（FavoriteRecord）は FavoriteSchemaV1 の入れ子型で、トップレベルの typealias から参照される。
 今後モデルを変更するときは、現行モデルを FavoriteSchemaV2 にコピーして変更し（V1 は凍結）、
 typealias の向き先を V2 へ替えて、stages に移行ステージを足す
 （アプリと Widget Extension は同じストアを開くため、どちらも AppGroupContainer 経由で本計画を使う）。
 */

import SwiftData

// MARK: - Schema

public enum FavoriteSchemaV1: VersionedSchema {
    public static let versionIdentifier = Schema.Version(1, 0, 0)
    public static var models: [any PersistentModel.Type] { [FavoriteRecord.self] }
}

// MARK: - Migration Plan

public enum FavoriteMigrationPlan: SchemaMigrationPlan {
    public static var schemas: [any VersionedSchema.Type] { [FavoriteSchemaV1.self] }
    /// V1 のみのため移行ステージなし（インデックスのみの変更は既存ストアに適用されないため、スキーマ変更はバージョンを上げて扱う）
    public static var stages: [MigrationStage] { [] }
}
