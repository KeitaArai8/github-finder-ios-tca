/*
 Abstract:
 検索結果の表示用構造体。Entityとお気に入り状態を統合しPassive Viewを実現。
 */

import Foundation
import GitHubFinderDomain

public nonisolated struct RepositoryDisplayItem: Equatable, Identifiable {
    public let id: Int
    public let fullName: String
    public let description: String?
    public let starCount: Int
    public let language: String?
    public let ownerAvatarURL: URL?
    public let isFavorite: Bool

    public init(repository: RepositoryEntity, isFavorite: Bool) {
        self.id = repository.id
        self.fullName = repository.fullName
        self.description = repository.description
        self.starCount = repository.starCount
        self.language = repository.language
        self.ownerAvatarURL = repository.ownerAvatarURL
        self.isFavorite = isFavorite
    }
}
