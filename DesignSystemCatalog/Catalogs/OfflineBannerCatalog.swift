/*
 Abstract:
 OfflineBanner のスタンドアロン表示。
 */

import SwiftUI
import GitHubFinderDesignSystem

struct OfflineBannerCatalog: View {
    var body: some View {
        VStack(spacing: 24) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Default").font(.caption).foregroundStyle(.secondary)
                OfflineBanner()
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("On Background").font(.caption).foregroundStyle(.secondary)
                ZStack(alignment: .top) {
                    Color(.systemBlue).opacity(0.1)
                        .frame(height: 200)
                    OfflineBanner()
                }
            }

            Spacer()
        }
        .padding()
        .navigationTitle("OfflineBanner")
    }
}

#Preview {
    NavigationStack { OfflineBannerCatalog() }
}
