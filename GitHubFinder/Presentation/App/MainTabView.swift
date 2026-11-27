/*
 Abstract:
 検索・お気に入り・設定の3タブを提供するメインタブ画面。
 */

import SwiftUI
import ComposableArchitecture
import FeatureSearch
import FeatureFavorite
import FeatureSettings

struct MainTabView: View {
    let store: StoreOf<AppFeature>

    var body: some View {
        TabView {
            Tab("検索", systemImage: "magnifyingglass", role: .search) {
                SearchView(store: store.scope(\.search, action: \.search))
            }

            Tab("お気に入り", systemImage: "heart.fill") {
                FavoriteListView(store: store.scope(\.favorite, action: \.favorite))
            }

            Tab("設定", systemImage: "gearshape") {
                SettingsView(store: store.scope(\.settings, action: \.settings))
            }
        }
        .tabBarMinimizeBehavior(.onScrollDown)
    }
}
