/*
 Abstract:
 UserDefaultsを使用したチュートリアル表示済みフラグの管理。
 Tutorial 機能でしか参照されないため FeatureTutorial 内に配置。
 */

import Foundation

public final class TutorialLocalDataSource {
    private static let hasCompletedKey = "hasCompletedTutorial"

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public var hasCompleted: Bool {
        defaults.bool(forKey: Self.hasCompletedKey)
    }

    public func markCompleted() {
        defaults.set(true, forKey: Self.hasCompletedKey)
    }
}
