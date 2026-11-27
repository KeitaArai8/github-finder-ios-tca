/*
 Abstract:
 タイポグラフィトークンの一覧表示。
 各 Font.app* トークンを実際のサイズで描画。
 */

import SwiftUI
import GitHubFinderDesignSystem

struct AppFontCatalog: View {
    private let tokens: [(name: String, font: Font, sample: String)] = [
        ("appTitleLarge", .appTitleLarge, "Title Large 大見出し"),
        ("appTitleMedium", .appTitleMedium, "Title Medium 中見出し"),
        ("appTitleSmall", .appTitleSmall, "Title Small 小見出し"),
        ("appBodyLarge", .appBodyLarge, "Body Large 本文 Hello World"),
        ("appBodyMedium", .appBodyMedium, "Body Medium 補助本文"),
        ("appBodySmall", .appBodySmall, "Body Small キャプション"),
        ("appLabelMedium", .appLabelMedium, "Label Medium ラベル"),
        ("appLabelSmall", .appLabelSmall, "Label Small 最小"),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.spacing250) {
                Text("Apple の Dynamic Type に紐付け、ユーザのテキストサイズ設定に追従する。")
                    .font(.appBodySmall)
                    .foregroundStyle(Color.Content.secondary)

                ForEach(tokens, id: \.name) { token in
                    VStack(alignment: .leading, spacing: Spacing.spacing50) {
                        Text(token.name)
                            .font(.appLabelSmall.monospaced())
                            .foregroundStyle(Color.Content.tertiary)
                        Text(token.sample)
                            .font(token.font)
                    }
                }
            }
            .padding(Spacing.spacing200)
        }
        .navigationTitle("AppFont")
    }
}

#Preview {
    NavigationStack { AppFontCatalog() }
}
