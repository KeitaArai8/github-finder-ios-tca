/*
 Abstract:
 タイポグラフィトークン。
 `Font.headline` 等の Apple セマンティックフォントを直接 View で使わず、
 役割（titleLarge / bodyMedium 等）ベースの命名で参照する。

 トークン分類:
   - title*  : タイトル系（screen header / section header / card header）
   - body*   : 本文系
   - label*  : ボタン・バッジ・キャプション等

 実体は Apple の Dynamic Type に紐付けているため、ユーザのテキストサイズ設定に追従する。
 */

import SwiftUI

public extension Font {
    /// 画面レベルのヘッダ（NavigationTitle 等）
    static let appTitleLarge: Font = .largeTitle.bold()
    /// セクションヘッダ
    static let appTitleMedium: Font = .title2.bold()
    /// カードヘッダ・行タイトル
    static let appTitleSmall: Font = .headline

    /// 主要な本文
    static let appBodyLarge: Font = .body
    /// 補助的な本文
    static let appBodyMedium: Font = .subheadline
    /// キャプション・補助情報
    static let appBodySmall: Font = .footnote

    /// ボタン・バッジ等のラベル
    static let appLabelMedium: Font = .caption
    /// 最小ラベル（メタ情報）
    static let appLabelSmall: Font = .caption2
}
