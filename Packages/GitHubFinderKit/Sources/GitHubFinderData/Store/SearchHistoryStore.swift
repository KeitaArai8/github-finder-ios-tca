/*
 Abstract:
 検索履歴の永続化を抽象化する protocol と、UserDefaults を使った本番実装。
 - 直近 maxEntries 件（デフォルト 10）を新しい順で保持
 - 同一クエリ追加時は重複を排除して先頭に移動
 - 空白のみ・空文字は無視
 - SearchModel 等の State Holder からは @Observable プロパティ history を購読する

 protocol 化の目的:
 - UserDefaults に依存しない Mock を導入し、テストでの状態リーク（テスト間の suite 干渉）を排除
 - Android の SearchHistoryDataSource (interface) と対称な設計に揃え、両 OS で同一の DI 思想を保つ
 */

import Foundation
import Observation
import os
import GitHubFinderDomain

/// 検索履歴 Store の抽象。SwiftUI の observation tracking を通すため `Observable` を継承する。
@MainActor
public protocol SearchHistoryStoreProtocol: AnyObject, Observable {
    /// 新しい順で保持される検索履歴。
    var history: [String] { get }
    /// クエリを履歴に追加（重複排除 + 先頭挿入 + 上限切り詰め）。空白のみは無視。
    func add(_ rawQuery: String)
    /// 単一エントリを削除する。
    func remove(_ query: String)
    /// 履歴を全消去する。
    func clear()
}

/// 検索履歴の本番実装。UserDefaults に永続化し、@Observable で UI に reactive に変更通知を行う。
@Observable
@MainActor
public final class SearchHistoryStore: SearchHistoryStoreProtocol {
    public private(set) var history: [String] = []

    private let userDefaults: UserDefaults
    private let storageKey: String
    private let maxEntries: Int

    public init(
        userDefaults: UserDefaults = .standard,
        storageKey: String = "search.history.v1",
        maxEntries: Int = 10
    ) {
        self.userDefaults = userDefaults
        self.storageKey = storageKey
        self.maxEntries = maxEntries
        load()
    }

    public func add(_ rawQuery: String) {
        let query = rawQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return }

        var updated = history.filter { $0 != query }
        updated.insert(query, at: 0)
        if updated.count > maxEntries {
            updated = Array(updated.prefix(maxEntries))
        }
        history = updated
        persist()
        Logger.search.info("Search history added: query=\(query, privacy: .public), total=\(updated.count)")
    }

    public func remove(_ query: String) {
        history.removeAll { $0 == query }
        persist()
        Logger.search.info("Search history removed: query=\(query, privacy: .public)")
    }

    public func clear() {
        history = []
        persist()
        Logger.search.info("Search history cleared")
    }

    // MARK: - Private

    private func load() {
        guard let stored = userDefaults.array(forKey: storageKey) as? [String] else {
            history = []
            return
        }
        // 念の為、保存済みデータも上限を尊重する（旧バージョンで maxEntries が大きかった場合の対策）
        history = Array(stored.prefix(maxEntries))
    }

    private func persist() {
        userDefaults.set(history, forKey: storageKey)
    }
}
