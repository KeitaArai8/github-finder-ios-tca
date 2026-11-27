/*
 Abstract:
 アプリ全体で利用する os.Logger の subsystem と category 別エントリポイント。
 機能ごとにカテゴリを分け、Console.app から `subsystem == "com.example.GitHubFinder"` で
 フィルタすることで構造化ログを活用できる。

 Domain target に置く理由: 全モジュールが Domain に（直接または推移的に）依存するため、
 ここに置けば Data / DesignSystem / Feature* のすべてから `Logger.search` 等を参照可能。
 */

import Foundation
import os

extension Logger {
    private static let subsystem = "com.example.GitHubFinder"

    /// 検索 / API 呼び出し関連
    public static let search = Logger(subsystem: subsystem, category: "search")

    /// お気に入り CRUD
    public static let favorite = Logger(subsystem: subsystem, category: "favorite")

    /// ネットワーク状態（Online/Offline）
    public static let network = Logger(subsystem: subsystem, category: "network")
}
