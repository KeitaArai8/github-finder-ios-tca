/*
 Abstract:
 セマンティック・カラートークン。
 `Color.red` / `Color.gray` / `Color(uiColor: .systemBackground)` を View で直接使わず、
 必ず役割（用途）ベースのトークンを経由する。

 トークン分類:
   - Background.*  : 画面・カード等の背景色
   - Content.*     : テキスト・アイコン等の前景色
   - Border.*      : 区切り線
   - Brand.*       : ブランド固有色（star, favorite 等）
   - Status.*      : 状態色（error/success/warning/info）

 すべて Apple のセマンティックシステムカラーに紐付けているため、
 ダークモード対応は自動。
 */

import SwiftUI
import UIKit

public extension Color {
    enum Background {
        /// メインの画面背景
        public static let primary = Color(uiColor: .systemBackground)
        /// セカンダリ（カード・グループ背景）
        public static let secondary = Color(uiColor: .secondarySystemBackground)
        /// ターシャリ（さらに奥のレイヤー）
        public static let tertiary = Color(uiColor: .tertiarySystemBackground)
        /// チップ・タグ等の控えめなサーフェス
        public static let surfaceMuted = Color(uiColor: .systemGray6)
    }

    enum Content {
        /// 主要テキスト
        public static let primary = Color.primary
        /// 補助テキスト
        public static let secondary = Color.secondary
        /// ターシャリ（プレースホルダ等）
        public static let tertiary = Color(uiColor: .tertiaryLabel)
        /// 反転（カラー背景上の白文字等）
        public static let inverse = Color.white
        /// アクセント色のテキスト・アイコン
        public static let accent = Color.accentColor
    }

    enum Border {
        /// 標準的な区切り線
        public static let primary = Color(uiColor: .separator)
        /// 控えめな区切り
        public static let subtle = Color(uiColor: .systemGray5)
    }

    enum Brand {
        /// お気に入り（ハート）色
        public static let favorite = Color.red
        /// Star 評価色
        public static let star = Color.orange
    }

    enum Status {
        public static let error = Color.red
        public static let success = Color.green
        public static let warning = Color.yellow
        public static let info = Color.blue
    }
}
