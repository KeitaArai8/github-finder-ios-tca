/*
 Abstract:
 App Group経由でアプリと Widget Extension が共有する SwiftData ModelContainer を提供する。
 両ターゲットで同じ SQLite ファイルを参照することで、お気に入りデータをウィジェットからも読み取れる。

 Data target 配置の理由:
 - FavoriteRecord schema を参照する必要があるため Data 内に配置
 - Widget Extension からは GitHubFinderData を import するだけで利用可能
 */

import Foundation
import SwiftData

public enum AppGroupContainerError: Error {
    /// App Groupのエンタイトルメント未設定や識別子不一致により、共有コンテナURLが取得できなかった。
    case containerURLUnavailable(identifier: String)
}

public enum AppGroupContainer {
    public static let identifier = "group.com.example.GitHubFinder"
    /// お気に入りウィジェットの kind。Widget 定義と `reloadTimelines(ofKind:)` で同じ値を使う。
    public static let favoriteWidgetKind = "FavoriteWidget"
    private static let databaseFileName = "GitHubFinder.sqlite"

    /// App Group配下のSwiftData ModelContainerを生成する。
    /// - Throws: App Groupが未設定の場合 `AppGroupContainerError.containerURLUnavailable`、
    ///           ModelContainer初期化失敗時はSwiftDataのエラー。
    public static func makeModelContainer() throws -> ModelContainer {
        let schema = Schema(versionedSchema: FavoriteSchemaV1.self)
        guard let containerURL = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: identifier)
        else {
            throw AppGroupContainerError.containerURLUnavailable(identifier: identifier)
        }
        let storeURL = containerURL.appending(path: databaseFileName)
        let configuration = ModelConfiguration(schema: schema, url: storeURL)
        return try ModelContainer(
            for: schema,
            migrationPlan: FavoriteMigrationPlan.self,
            configurations: [configuration]
        )
    }
}
