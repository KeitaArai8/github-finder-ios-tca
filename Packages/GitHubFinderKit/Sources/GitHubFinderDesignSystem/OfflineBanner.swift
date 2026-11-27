/*
 Abstract:
 オフライン時にアプリ最上部に表示するバナー View。
 NetworkMonitor.isConnected が false のときに AppRootView から safeAreaBar として表示される。
 */

import SwiftUI

public struct OfflineBanner: View {
    public init() {}

    public var body: some View {
        HStack(spacing: Spacing.spacing100) {
            Image(systemName: "wifi.slash")
            Text("オフライン", bundle: #bundle)
        }
        .font(.appLabelMedium.bold())
        .foregroundStyle(Color.Content.inverse)
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.spacing100)
        .padding(.horizontal, Spacing.spacing200)
        .background(Color.Status.error)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("ネットワークに接続されていません", bundle: #bundle))
    }
}

#if DEBUG
#Preview {
    VStack(spacing: 0) {
        OfflineBanner()
        Spacer()
    }
}
#endif
