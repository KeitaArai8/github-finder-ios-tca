/*
 Abstract:
 セマンティックカラートークンの一覧表示。
 Background / Content / Border / Brand / Status の 5 グループを用途別に確認できる。
 */

import SwiftUI
import GitHubFinderDesignSystem

struct AppColorCatalog: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.spacing400) {
                section(title: "Background", samples: [
                    ("primary", Color.Background.primary),
                    ("secondary", Color.Background.secondary),
                    ("tertiary", Color.Background.tertiary),
                    ("surfaceMuted", Color.Background.surfaceMuted),
                ])

                section(title: "Content", samples: [
                    ("primary", Color.Content.primary),
                    ("secondary", Color.Content.secondary),
                    ("tertiary", Color.Content.tertiary),
                    ("inverse", Color.Content.inverse),
                    ("accent", Color.Content.accent),
                ])

                section(title: "Border", samples: [
                    ("primary", Color.Border.primary),
                    ("subtle", Color.Border.subtle),
                ])

                section(title: "Brand", samples: [
                    ("favorite", Color.Brand.favorite),
                    ("star", Color.Brand.star),
                ])

                section(title: "Status", samples: [
                    ("error", Color.Status.error),
                    ("success", Color.Status.success),
                    ("warning", Color.Status.warning),
                    ("info", Color.Status.info),
                ])
            }
            .padding(Spacing.spacing200)
        }
        .navigationTitle("AppColor")
    }

    private func section(title: String, samples: [(name: String, color: Color)]) -> some View {
        VStack(alignment: .leading, spacing: Spacing.spacing150) {
            Text(title)
                .font(.appTitleSmall)
                .foregroundStyle(Color.Content.primary)
            ForEach(samples, id: \.name) { sample in
                HStack(spacing: Spacing.spacing150) {
                    RoundedRectangle(cornerRadius: Radius.radius50)
                        .fill(sample.color)
                        .frame(width: 56, height: 32)
                        .overlay(
                            RoundedRectangle(cornerRadius: Radius.radius50)
                                .stroke(Color.Border.subtle, lineWidth: 0.5)
                        )
                    Text(sample.name)
                        .font(.appLabelMedium.monospaced())
                        .foregroundStyle(Color.Content.secondary)
                }
            }
        }
    }
}

#Preview {
    NavigationStack { AppColorCatalog() }
}
