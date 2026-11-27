/*
 Abstract:
 チュートリアル対象UIの画面上の矩形座標を、各Viewから CoachMarkOverlay へ
 伝搬するための PreferenceKey と便利な View 拡張。
 */

import SwiftUI

public struct CoachMarkFramePreferenceKey: PreferenceKey {
    // Swift 6 strict concurrency 向けに let で宣言（PreferenceKey の getter 要件を満たす）
    public static let defaultValue: [TutorialFeature.Step: CGRect] = [:]

    public static func reduce(
        value: inout [TutorialFeature.Step: CGRect],
        nextValue: () -> [TutorialFeature.Step: CGRect]
    ) {
        value.merge(nextValue()) { _, new in new }
    }
}

extension View {
    /// 対象Viewのグローバル座標を指定ステップ用のアンカーとして報告する。
    /// CoachMarkOverlay はこの座標をもとにスポットライトと吹き出しを配置する。
    public func coachMarkAnchor(for step: TutorialFeature.Step) -> some View {
        background {
            GeometryReader { geo in
                Color.clear
                    .preference(
                        key: CoachMarkFramePreferenceKey.self,
                        value: [step: geo.frame(in: .global)]
                    )
            }
        }
    }
}
