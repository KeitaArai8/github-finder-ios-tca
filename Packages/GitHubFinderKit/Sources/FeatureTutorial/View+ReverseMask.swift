/*
 Abstract:
 SwiftUIの View にマスクの「逆」を適用する拡張。スポットライト型オーバーレイで
 「暗転背景の中で対象UIだけ穴を空ける」用途に利用する。
 */

import SwiftUI

extension View {
    /// 指定の形状部分だけ透明化するマスク処理。通常の mask と逆の挙動。
    func reverseMask<Mask: View>(@ViewBuilder _ mask: () -> Mask) -> some View {
        self.mask {
            Rectangle()
                .overlay(mask().blendMode(.destinationOut))
        }
    }
}
