/*
 Abstract:
 FavoriteSchemaV1 のエンティティ名を固定する回帰テスト。
 */

import SwiftData
import Testing
@testable import GitHubFinderData

@Suite("FavoriteSchemaV1")
struct FavoriteSchemaTests {

    @Test("入れ子の @Model でもエンティティ名は FavoriteRecord のまま")
    func entityNameStaysFavoriteRecord() {
        // Arrange: 共有ストア（App Group）が使うスキーマ
        let schema = Schema(versionedSchema: FavoriteSchemaV1.self)

        // Act: エンティティ名を取り出す
        let names = schema.entities.map(\.name)

        // Assert: 既存ストアのエンティティ名と一致している（変わるとデータが読めなくなる）
        #expect(names == ["FavoriteRecord"])
    }
}
