/*
 Abstract:
 ErrorView の各エラーパターンをカタログ表示する。
 */

import SwiftUI
import GitHubFinderDesignSystem

struct ErrorViewCatalog: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                catalogItem(title: "Network Error") {
                    ErrorView(message: "ネットワークに接続できません", onRetry: {})
                }
                catalogItem(title: "Rate Limit") {
                    ErrorView(message: "API 利用制限に達しました。\nしばらく待ってから再試行してください。", onRetry: {})
                }
                catalogItem(title: "Server Error (500)") {
                    ErrorView(message: "サーバーエラーが発生しました（500）", onRetry: {})
                }
                catalogItem(title: "Unknown") {
                    ErrorView(message: "予期せぬエラーが発生しました", onRetry: {})
                }
            }
            .padding()
        }
        .navigationTitle("ErrorView")
    }

    @ViewBuilder
    private func catalogItem<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            content()
                .frame(height: 200)
                .background(Color(.systemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}

#Preview {
    NavigationStack { ErrorViewCatalog() }
}
