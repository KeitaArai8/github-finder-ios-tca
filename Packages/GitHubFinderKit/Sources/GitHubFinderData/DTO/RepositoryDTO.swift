/*
 Abstract:
 GitHub API のリポジトリ情報をデコードするためのDTO。Data target 内部実装のため非 public。
 */

import Foundation
import GitHubFinderDomain

struct RepositoryDTO: Decodable, Sendable {
    let id: Int
    let fullName: String
    let description: String?
    let stargazersCount: Int
    let language: String?
    let owner: OwnerDTO

    func toEntity() -> RepositoryEntity {
        RepositoryEntity(
            id: id,
            fullName: fullName,
            description: description,
            starCount: stargazersCount,
            language: language,
            ownerAvatarURL: URL(string: owner.avatarURL)
        )
    }
}

// MARK: - OwnerDTO

struct OwnerDTO: Decodable, Sendable {
    let avatarURL: String

    enum CodingKeys: String, CodingKey {
        // JSON は avatar_url。convertFromSnakeCase 後のキーは avatarUrl（URL 大文字表記と一致しない）ため明示的に対応づける
        case avatarURL = "avatarUrl"
    }
}
