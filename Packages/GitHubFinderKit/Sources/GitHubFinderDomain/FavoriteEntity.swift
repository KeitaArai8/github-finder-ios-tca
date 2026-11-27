/*
 Abstract:
 お気に入りに保存されたリポジトリを表すドメインエンティティ。
 */

import Foundation

public struct FavoriteEntity: Equatable, Identifiable, Sendable {
    public let id: Int
    public let fullName: String
    public let description: String?
    public let starCount: Int
    public let language: String?
    public let ownerAvatarURL: URL?
    public let savedAt: Date

    public init(
        id: Int,
        fullName: String,
        description: String?,
        starCount: Int,
        language: String?,
        ownerAvatarURL: URL?,
        savedAt: Date
    ) {
        self.id = id
        self.fullName = fullName
        self.description = description
        self.starCount = starCount
        self.language = language
        self.ownerAvatarURL = ownerAvatarURL
        self.savedAt = savedAt
    }
}
