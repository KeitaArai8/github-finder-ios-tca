/*
 Abstract:
 角丸（corner radius）トークン。`RoundedRectangle(cornerRadius:)` 等に直接数値を渡さず
 必ずこのトークンを経由する。

 命名規則:
   - radius50  =  4 (極小・チップ等)
   - radius100 =  8 (アイコン・小カード)
   - radius150 = 12 (中カード)
   - radius200 = 16 (大カード)
   - radiusFull = 999 (完全な丸・カプセル形状)
 */

import Foundation

public enum Radius {
    public static let radius50: CGFloat = 4
    public static let radius100: CGFloat = 8
    public static let radius150: CGFloat = 12
    public static let radius200: CGFloat = 16
    public static let radiusFull: CGFloat = 999
}
