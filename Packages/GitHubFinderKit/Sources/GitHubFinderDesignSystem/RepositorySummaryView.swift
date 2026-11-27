/*
 Abstract:
 リポジトリ 1 件のアバター・名前・説明・Star 数・言語を表示する共通コンテンツ。
 検索結果行（RepositoryDisplayItem）とお気に入り行（FavoriteEntity）が同じ見た目を共有するため、
 呼び出し側の型に依存しない primitive な値で受け取る。
 行全体の Button 構造・アクセシビリティ・編集モードの扱いは呼び出し側が持つ。
 */

import SwiftUI

public struct RepositorySummaryView: View {
    let fullName: String
    let description: String?
    let starCount: Int
    let language: String?
    let ownerAvatarURL: URL?

    public init(
        fullName: String,
        description: String?,
        starCount: Int,
        language: String?,
        ownerAvatarURL: URL?
    ) {
        self.fullName = fullName
        self.description = description
        self.starCount = starCount
        self.language = language
        self.ownerAvatarURL = ownerAvatarURL
    }

    public var body: some View {
        HStack(alignment: .center, spacing: Spacing.spacing150) {
            avatarImage
            repositoryInfo
        }
    }

    private var avatarImage: some View {
        AsyncImage(url: ownerAvatarURL) { image in
            image.resizable()
        } placeholder: {
            Color.Border.subtle
        }
        .frame(width: Spacing.spacing500, height: Spacing.spacing500) // 40pt
        .clipShape(RoundedRectangle(cornerRadius: Radius.radius100))
    }

    private var repositoryInfo: some View {
        VStack(alignment: .leading, spacing: Spacing.spacing50) {
            Text(fullName)
                .font(.appTitleSmall)
                .lineLimit(1)

            if let description {
                Text(description)
                    .font(.appBodyMedium)
                    .foregroundStyle(Color.Content.secondary)
                    .lineLimit(2)
            }

            HStack(spacing: Spacing.spacing150) {
                Label("\(starCount)", systemImage: "star.fill")
                    .foregroundStyle(Color.Brand.star)

                if let language {
                    Text(language)
                        .foregroundStyle(Color.Content.secondary)
                }
            }
            .font(.appLabelMedium)
        }
    }
}

#Preview("description・language あり / なし") {
    List {
        RepositorySummaryView(
            fullName: "apple/swift",
            description: "The Swift Programming Language",
            starCount: 67_000,
            language: "C++",
            ownerAvatarURL: nil
        )
        RepositorySummaryView(
            fullName: "owner/no-description",
            description: nil,
            starCount: 12,
            language: "Swift",
            ownerAvatarURL: nil
        )
        RepositorySummaryView(
            fullName: "owner/no-language",
            description: "language が無いリポジトリ",
            starCount: 3,
            language: nil,
            ownerAvatarURL: nil
        )
        RepositorySummaryView(
            fullName: "owner/minimal",
            description: nil,
            starCount: 0,
            language: nil,
            ownerAvatarURL: nil
        )
    }
}
