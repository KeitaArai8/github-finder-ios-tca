/*
 Abstract:
 SettingsFeature の状態遷移を TestStore でテストする。
 */

import ComposableArchitecture
import Foundation
import Testing
import GitHubFinderDesignSystem
@testable import FeatureSettings

@Suite("SettingsFeature")
@MainActor
struct SettingsFeatureTests {

    @Test("プライバシーポリシーをタップすると Safari シートで開く")
    func privacyPolicyTappedPresentsSafari() async throws {
        // Arrange: 何も表示していない初期状態
        let store = TestStore(initialState: SettingsFeature.State()) {
            SettingsFeature()
        }
        let url = try #require(URL(string: "https://www.apple.com/legal/privacy/"))

        // Act: 「プライバシーポリシー」をタップ
        await store.send(.view(.privacyPolicyTapped)) {
            // Assert: プライバシーポリシーの URL が Safari シートの表示対象になる
            $0.destination = .safari(SafariDestination(url: url))
        }
        await store.finish()
    }

    @Test("利用規約をタップすると Safari シートで開く")
    func termsTappedPresentsSafari() async throws {
        // Arrange: 何も表示していない初期状態
        let store = TestStore(initialState: SettingsFeature.State()) {
            SettingsFeature()
        }
        let url = try #require(URL(string: "https://www.apple.com/legal/internet-services/itunes/"))

        // Act: 「利用規約」をタップ
        await store.send(.view(.termsTapped)) {
            // Assert: 利用規約の URL が Safari シートの表示対象になる
            $0.destination = .safari(SafariDestination(url: url))
        }
        await store.finish()
    }
}
