/*
 Abstract:
 スポットライト対象UIの位置に重ねて、外側に広がる脈動リングを描画するオーバーレイ。
 CoachMarkOverlayが現在のステップの矩形にこのViewを配置する。
 */

import SwiftUI

struct PulseRing: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var animate = false

    var body: some View {
        // 「視差効果を減らす」では脈動（拡大しながらフェードアウトの繰り返し）を止め、静止したリングで強調する
        RoundedRectangle(cornerRadius: 14)
            .stroke(Color.white, lineWidth: 3)
            .scaleEffect(animate && !reduceMotion ? 1.25 : 1.0)
            .opacity(animate && !reduceMotion ? 0 : 0.9)
            .animation(
                reduceMotion ? nil : .easeOut(duration: 1.4).repeatForever(autoreverses: false),
                value: animate
            )
            .onAppear { animate = true }
    }
}
