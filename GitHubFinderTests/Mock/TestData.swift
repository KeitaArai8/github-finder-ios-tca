/*
 Abstract:
 テスト用のサンプルデータ生成ヘルパー。
 */

import Foundation
import GitHubFinderDomain

enum TestData {
    static func makeRepository(
        id: Int = 1,
        fullName: String = "owner/repo",
        description: String? = "A test repository",
        starCount: Int = 100,
        language: String? = "Swift",
        ownerAvatarURL: URL? = URL(string: "https://example.com/avatar.png")
    ) -> RepositoryEntity {
        RepositoryEntity(
            id: id,
            fullName: fullName,
            description: description,
            starCount: starCount,
            language: language,
            ownerAvatarURL: ownerAvatarURL
        )
    }

    static func makeSearchResult(
        items: [RepositoryEntity]? = nil,
        totalCount: Int? = nil,
        hasNextPage: Bool = false
    ) -> SearchResultEntity {
        let repos = items ?? [makeRepository()]
        return SearchResultEntity(
            totalCount: totalCount ?? repos.count,
            items: repos,
            hasNextPage: hasNextPage
        )
    }

    static func makeFavorite(
        id: Int = 1,
        fullName: String = "owner/repo",
        starCount: Int = 100,
        language: String? = "Swift",
        savedAt: Date = Date()
    ) -> FavoriteEntity {
        FavoriteEntity(
            id: id,
            fullName: fullName,
            description: "A test repository",
            starCount: starCount,
            language: language,
            ownerAvatarURL: URL(string: "https://example.com/avatar.png"),
            savedAt: savedAt
        )
    }
}
