/*
 Abstract:
 GitHubリポジトリを表すドメインエンティティ。
 */

import Foundation

public struct RepositoryEntity: Equatable, Identifiable, Sendable {
    public let id: Int
    public let fullName: String
    public let description: String?
    public let starCount: Int
    public let language: String?
    public let ownerAvatarURL: URL?

    public init(
        id: Int,
        fullName: String,
        description: String?,
        starCount: Int,
        language: String?,
        ownerAvatarURL: URL?
    ) {
        self.id = id
        self.fullName = fullName
        self.description = description
        self.starCount = starCount
        self.language = language
        self.ownerAvatarURL = ownerAvatarURL
    }
}
