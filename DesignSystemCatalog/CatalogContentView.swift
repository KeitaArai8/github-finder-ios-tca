/*
 Abstract:
 DesignSystemCatalog のトップレベル NavigationStack。
 各 DS コンポーネントへ NavigationLink で遷移する。
 新しい DS 部品を追加した際は、ここに 1 行追加するだけでカタログに載る。
 */

import SwiftUI

struct CatalogContentView: View {
    var body: some View {
        NavigationStack {
            List {
                Section("Tokens") {
                    NavigationLink("Spacing", destination: SpacingCatalog())
                    NavigationLink("Radius", destination: RadiusCatalog())
                    NavigationLink("AppColor", destination: AppColorCatalog())
                    NavigationLink("AppFont", destination: AppFontCatalog())
                }

                Section("UI Components") {
                    NavigationLink("ErrorView", destination: ErrorViewCatalog())
                    NavigationLink("OfflineBanner", destination: OfflineBannerCatalog())
                    NavigationLink("SafariView", destination: SafariViewCatalog())
                }

                Section("Display Models") {
                    NavigationLink("RepositoryDisplayItem", destination: RepositoryDisplayItemCatalog())
                }

                Section("State Containers") {
                    NavigationLink("ViewState", destination: ViewStateCatalog())
                }

                Section("Helpers") {
                    NavigationLink("GitHubURL", destination: GitHubURLCatalog())
                }
            }
            .navigationTitle("DS Catalog")
        }
    }
}

#Preview {
    CatalogContentView()
}
