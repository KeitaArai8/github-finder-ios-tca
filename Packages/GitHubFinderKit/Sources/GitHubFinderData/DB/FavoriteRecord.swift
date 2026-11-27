/*
 Abstract:
 SwiftDataで永続化するお気に入りレコードのモデル定義。
 Widget Extension からも fetch されるため public。
 モデルは Apple のサンプルに倣い FavoriteSchemaV1 に入れ子にし、既存コードは
 トップレベルの typealias（FavoriteRecord）経由で参照する。
 */

import Foundation
import SwiftData
import GitHubFinderDomain

// MARK: - Model

extension FavoriteSchemaV1 {
    @Model
    public final class FavoriteRecord {
        @Attribute(.unique) public var repositoryID: Int
        public var fullName: String
        public var descriptionText: String?
        public var starCount: Int
        public var language: String?
        public var ownerAvatarURL: String?
        public var savedAt: Date

        public init(
            repositoryID: Int,
            fullName: String,
            descriptionText: String?,
            starCount: Int,
            language: String?,
            ownerAvatarURL: String?,
            savedAt: Date = .now
        ) {
            self.repositoryID = repositoryID
            self.fullName = fullName
            self.descriptionText = descriptionText
            self.starCount = starCount
            self.language = language
            self.ownerAvatarURL = ownerAvatarURL
            self.savedAt = savedAt
        }

        // MARK: - Conversion

        public func toEntity() -> FavoriteEntity {
            FavoriteEntity(
                id: repositoryID,
                fullName: fullName,
                description: descriptionText,
                starCount: starCount,
                language: language,
                ownerAvatarURL: ownerAvatarURL.flatMap { URL(string: $0) },
                savedAt: savedAt
            )
        }

        public convenience init(repository: RepositoryEntity) {
            self.init(
                repositoryID: repository.id,
                fullName: repository.fullName,
                descriptionText: repository.description,
                starCount: repository.starCount,
                language: repository.language,
                ownerAvatarURL: repository.ownerAvatarURL?.absoluteString
            )
        }
    }
}

// MARK: - Current version alias

/// 現行バージョンのモデル。スキーマを V2 に上げるときは、この typealias の向き先を差し替える。
public typealias FavoriteRecord = FavoriteSchemaV1.FavoriteRecord
