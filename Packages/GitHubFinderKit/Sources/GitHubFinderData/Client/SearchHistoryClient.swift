/*
 Abstract:
 検索履歴の読み書きを Reducer へ公開する依存クライアント。
 本番実装は SearchHistoryStore（UserDefaults 永続化）の薄いラッパー。
 書き込み系の操作は、操作後の履歴（新しい順）を返す。
 */

import Dependencies
import DependenciesMacros

@DependencyClient
public struct SearchHistoryClient: Sendable {
    /// 保存済みの履歴（新しい順）
    public var history: @Sendable () async -> [String] = { [] }
    /// クエリを履歴に追加し、追加後の履歴を返す
    public var add: @Sendable (_ query: String) async -> [String] = { _ in [] }
    /// 1 件を履歴から削除し、削除後の履歴を返す
    public var remove: @Sendable (_ query: String) async -> [String] = { _ in [] }
    /// 履歴を全消去する
    public var clear: @Sendable () async -> Void
}

extension SearchHistoryClient: DependencyKey {
    public static let liveValue = SearchHistoryClient(
        history: { @MainActor in
            LiveSearchHistoryStore.shared.history
        },
        add: { @MainActor query in
            LiveSearchHistoryStore.shared.add(query)
            return LiveSearchHistoryStore.shared.history
        },
        remove: { @MainActor query in
            LiveSearchHistoryStore.shared.remove(query)
            return LiveSearchHistoryStore.shared.history
        },
        clear: { @MainActor in
            LiveSearchHistoryStore.shared.clear()
        }
    )

    public static let testValue = SearchHistoryClient()
}

@MainActor
private enum LiveSearchHistoryStore {
    static let shared = SearchHistoryStore()
}

extension DependencyValues {
    public var searchHistoryClient: SearchHistoryClient {
        get { self[SearchHistoryClient.self] }
        set { self[SearchHistoryClient.self] = newValue }
    }
}
