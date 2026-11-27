/*
 Abstract:
 エラーメッセージとリトライボタンを表示する共通コンポーネント。
 */

import SwiftUI

public struct ErrorView: View {
    let message: String
    let onRetry: () -> Void

    public init(message: String, onRetry: @escaping () -> Void) {
        self.message = message
        self.onRetry = onRetry
    }

    public var body: some View {
        ContentUnavailableView {
            Label(LocalizedStringResource("エラー", bundle: #bundle), systemImage: "exclamationmark.triangle")
        } description: {
            Text(message)
        } actions: {
            Button(LocalizedStringResource("再試行", bundle: #bundle)) {
                onRetry()
            }
            .buttonStyle(.borderedProminent)
        }
    }
}

#if DEBUG
#Preview("Network Error") {
    ErrorView(message: "ネットワークに接続できません", onRetry: {})
}

#Preview("Rate Limit") {
    ErrorView(message: "API 利用制限に達しました。しばらく待ってから再試行してください。", onRetry: {})
}
#endif
