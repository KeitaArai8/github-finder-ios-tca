/*
 Abstract:
 アプリ全体で使うスペーシングトークン。8pt グリッドベース。
 ハードコードされた数値（`16`, `8` など）を直接 padding/spacing に渡さず、
 必ずこのトークンを経由することで、デザイン変更を一箇所で吸収できるようにする。

 命名規則: spacing{倍数 × 100}
   - spacing50  =  4 (0.5x)
   - spacing100 =  8 (1x)
   - spacing150 = 12 (1.5x)
   - spacing200 = 16 (2x)
   - spacing300 = 24 (3x)
   - spacing400 = 32 (4x)
   - spacing500 = 40 (5x)
 */

import Foundation

public enum Spacing {
    public static let spacing50: CGFloat = 4
    public static let spacing100: CGFloat = 8
    public static let spacing150: CGFloat = 12
    public static let spacing200: CGFloat = 16
    public static let spacing250: CGFloat = 20
    public static let spacing300: CGFloat = 24
    public static let spacing400: CGFloat = 32
    public static let spacing500: CGFloat = 40
    public static let spacing600: CGFloat = 48
}
