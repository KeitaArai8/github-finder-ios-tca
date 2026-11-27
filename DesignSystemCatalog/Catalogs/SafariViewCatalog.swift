/*
 Abstract:
 SafariView のラッパー動作確認カタログ。
 */

import SwiftUI
import GitHubFinderDesignSystem

struct SafariViewCatalog: View {
    @State private var isPresented = false
    private let sampleURL = URL(string: "https://github.com")!

    var body: some View {
        VStack(spacing: 24) {
            Text("SafariView は SFSafariViewController を SwiftUI でラップする。")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.leading)

            Button("Open https://github.com") {
                isPresented = true
            }
            .buttonStyle(.borderedProminent)

            Spacer()
        }
        .padding()
        .navigationTitle("SafariView")
        .sheet(isPresented: $isPresented) {
            SafariView(url: sampleURL)
        }
    }
}

#Preview {
    NavigationStack { SafariViewCatalog() }
}
