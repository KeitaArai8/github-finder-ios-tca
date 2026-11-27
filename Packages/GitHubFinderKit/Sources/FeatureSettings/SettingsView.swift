/*
 Abstract:
 アプリの設定画面。法的情報とバージョン情報を表示。
 */

import SwiftUI
import ComposableArchitecture
import GitHubFinderDesignSystem

@ViewAction(for: SettingsFeature.self)
public struct SettingsView: View {
    @Bindable public var store: StoreOf<SettingsFeature>

    public init(store: StoreOf<SettingsFeature>) {
        self.store = store
    }

    public var body: some View {
        NavigationStack {
            List {
                Section(LocalizedStringResource("法的情報", bundle: #bundle)) {
                    Button {
                        send(.privacyPolicyTapped)
                    } label: {
                        Label(LocalizedStringResource("プライバシーポリシー", bundle: #bundle), systemImage: "hand.raised")
                    }

                    Button {
                        send(.termsTapped)
                    } label: {
                        Label(LocalizedStringResource("利用規約", bundle: #bundle), systemImage: "doc.text")
                    }
                }

                Section(LocalizedStringResource("アプリ情報", bundle: #bundle)) {
                    HStack {
                        Text("バージョン", bundle: #bundle)
                        Spacer()
                        Text(appVersion)
                            .foregroundStyle(Color.Content.secondary)
                    }
                }
            }
            .navigationTitle(LocalizedStringResource("設定", bundle: #bundle))
            .sheet(item: $store.scope(\.$destination, action: \.destination).safari) { destination in
                SafariView(url: destination.url)
            }
        }
    }

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
}

#if DEBUG
#Preview {
    SettingsView(store: Store(initialState: SettingsFeature.State()) {
        SettingsFeature()
    })
}
#endif
