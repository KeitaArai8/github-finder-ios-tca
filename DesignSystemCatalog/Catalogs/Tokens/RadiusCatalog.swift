/*
 Abstract:
 Radius トークンのビジュアル一覧。各 radius を実サイズ + サンプル矩形で確認できる。
 */

import SwiftUI
import GitHubFinderDesignSystem

struct RadiusCatalog: View {
    private let tokens: [(name: String, value: CGFloat)] = [
        ("radius50", Radius.radius50),
        ("radius100", Radius.radius100),
        ("radius150", Radius.radius150),
        ("radius200", Radius.radius200),
        ("radiusFull", Radius.radiusFull),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.spacing300) {
                Text("`RoundedRectangle(cornerRadius:)` には必ずこのトークンを使う。")
                    .font(.appBodySmall)
                    .foregroundStyle(Color.Content.secondary)
                    .padding(.horizontal, Spacing.spacing200)

                ForEach(tokens, id: \.name) { token in
                    HStack(spacing: Spacing.spacing200) {
                        RoundedRectangle(cornerRadius: token.value)
                            .fill(Color.Content.accent)
                            .frame(width: 80, height: 80)
                        VStack(alignment: .leading, spacing: Spacing.spacing50) {
                            Text(token.name)
                                .font(.appLabelMedium.monospaced())
                            Text("\(Int(token.value))pt")
                                .font(.appLabelSmall.monospaced())
                                .foregroundStyle(Color.Content.tertiary)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, Spacing.spacing200)
                }
            }
            .padding(.vertical, Spacing.spacing300)
        }
        .navigationTitle("Radius")
    }
}

#Preview {
    NavigationStack { RadiusCatalog() }
}
