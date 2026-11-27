/*
 Abstract:
 RepositoryDisplayItem の表示確認カタログ。
 GitHubFinderDomain の RepositoryEntity から構築されることを示す。
 */

import SwiftUI
import GitHubFinderDomain
import GitHubFinderDesignSystem

struct RepositoryDisplayItemCatalog: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("RepositoryDisplayItem は Entity + isFavorite を統合した Passive View 用構造体。")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                catalogItem("Sample 1: Not Favorite", item: Self.sample1)
                catalogItem("Sample 2: Favorite", item: Self.sample2)
                catalogItem("Sample 3: 言語 nil", item: Self.sample3)
                catalogItem("Sample 4: Description nil", item: Self.sample4)
            }
            .padding()
        }
        .navigationTitle("RepositoryDisplayItem")
    }

    @ViewBuilder
    private func catalogItem(_ title: String, item: RepositoryDisplayItem) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            HStack(alignment: .center, spacing: 12) {
                Color.gray.opacity(0.3)
                    .frame(width: 40, height: 40)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.fullName).font(.headline).lineLimit(1)
                    if let desc = item.description {
                        Text(desc).font(.subheadline).foregroundStyle(.secondary).lineLimit(2)
                    }
                    HStack(spacing: 12) {
                        Label("\(item.starCount)", systemImage: "star.fill")
                            .foregroundStyle(.orange)
                        if let lang = item.language {
                            Text(lang).foregroundStyle(.secondary)
                        }
                    }
                    .font(.caption)
                }
                Spacer()
                Image(systemName: item.isFavorite ? "heart.fill" : "heart")
                    .foregroundStyle(item.isFavorite ? .red : .gray)
            }
            .padding()
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8).stroke(Color(.separator), lineWidth: 0.5)
            )
        }
    }

    // MARK: - Samples

    private static let sample1 = RepositoryDisplayItem(
        repository: RepositoryEntity(
            id: 1,
            fullName: "apple/swift",
            description: "The Swift Programming Language",
            starCount: 67_000,
            language: "C++",
            ownerAvatarURL: nil
        ),
        isFavorite: false
    )

    private static let sample2 = RepositoryDisplayItem(
        repository: RepositoryEntity(
            id: 2,
            fullName: "pointfreeco/swift-composable-architecture",
            description: "A library for building applications in a consistent and understandable way",
            starCount: 13_000,
            language: "Swift",
            ownerAvatarURL: nil
        ),
        isFavorite: true
    )

    private static let sample3 = RepositoryDisplayItem(
        repository: RepositoryEntity(
            id: 3,
            fullName: "user/no-language-repo",
            description: "Language が nil のケース",
            starCount: 100,
            language: nil,
            ownerAvatarURL: nil
        ),
        isFavorite: false
    )

    private static let sample4 = RepositoryDisplayItem(
        repository: RepositoryEntity(
            id: 4,
            fullName: "user/no-description",
            description: nil,
            starCount: 5,
            language: "Swift",
            ownerAvatarURL: nil
        ),
        isFavorite: false
    )
}

#Preview {
    NavigationStack { RepositoryDisplayItemCatalog() }
}
