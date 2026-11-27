/*
 Abstract:
 Spacing トークンのビジュアル一覧。
 各 spacing 値を青いバーで描画し、実サイズを直感的に確認できる。
 */

import SwiftUI
import GitHubFinderDesignSystem

struct SpacingCatalog: View {
    private let tokens: [(name: String, value: CGFloat)] = [
        ("spacing50", Spacing.spacing50),
        ("spacing100", Spacing.spacing100),
        ("spacing150", Spacing.spacing150),
        ("spacing200", Spacing.spacing200),
        ("spacing250", Spacing.spacing250),
        ("spacing300", Spacing.spacing300),
        ("spacing400", Spacing.spacing400),
        ("spacing500", Spacing.spacing500),
        ("spacing600", Spacing.spacing600),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.spacing200) {
                Text("8pt グリッドベースの spacing トークン。padding / spacing には必ずこれを使う。")
                    .font(.appBodySmall)
                    .foregroundStyle(Color.Content.secondary)
                    .padding(.horizontal, Spacing.spacing200)

                ForEach(tokens, id: \.name) { token in
                    HStack(spacing: Spacing.spacing150) {
                        Text(token.name)
                            .font(.appLabelMedium.monospaced())
                            .frame(width: 120, alignment: .leading)
                        Rectangle()
                            .fill(Color.Content.accent)
                            .frame(width: token.value, height: 24)
                        Text("\(Int(token.value))pt")
                            .font(.appLabelSmall.monospaced())
                            .foregroundStyle(Color.Content.tertiary)
                    }
                    .padding(.horizontal, Spacing.spacing200)
                }
            }
            .padding(.vertical, Spacing.spacing300)
        }
        .navigationTitle("Spacing")
    }
}

#Preview {
    NavigationStack { SpacingCatalog() }
}
