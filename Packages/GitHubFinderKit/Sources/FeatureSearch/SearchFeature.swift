/*
 Abstract:
 リポジトリ検索画面の Reducer。キーワード検索（debounce）・ページ追加読み込み・お気に入りトグル・検索履歴を担当する。
 */

import ComposableArchitecture
import Foundation
import os
import GitHubFinderDomain
import GitHubFinderData
import GitHubFinderDesignSystem

@Reducer
public struct SearchFeature: Sendable {
    @Reducer
    public enum Destination {
        @ReducerCaseIgnored
        case alert(AlertState<Never>)
        @ReducerCaseIgnored
        case safari(SafariDestination)

        // Action を持つのは alert だけ。safari は表示データのみで Action を持たない
        @CasePathable
        public enum Action {
            case alert(Never)
        }
    }

    @ObservableState
    public struct State: Equatable {
        @Presents public var destination: Destination.State?
        public var searchQuery = ""
        /// 検索履歴（新しい順）
        public var history: [String] = []
        public var isLoadingMore = false

        /// お気に入り一覧。お気に入り画面と共有する（どちらの画面の変更も、もう一方へすぐ反映される）。
        /// 行にコピーせず、`viewState` の導出時に結合する
        @Shared var favorites: [FavoriteEntity]
        var items: [RepositoryEntity] = []
        var currentPage = 1
        var hasNextPage = false
        /// 直近に検索を開始したクエリ。同じクエリでの再実行（タブ復帰時など）を避けるために保持する。
        /// 完了しなかった検索（キャンセル・失敗）では nil に戻す
        var lastSearchedQuery: String?
        /// 1 ページ目の検索を実行中か（キャンセルされた検索は次の検索かリセットまで true のまま残る）
        var isSearching = false
        /// 直近の検索が失敗したときのエラー文言
        var searchError: String?

        public init(favorites: Shared<[FavoriteEntity]>) {
            self._favorites = favorites
        }

        /// 画面のフェーズ。保存せず、検索の事実（`isSearching` / `searchError` / `lastSearchedQuery`）と
        /// 元データ（`items` / `favorites`）から都度導出する
        public var viewState: ViewState<[RepositoryDisplayItem]> {
            if isSearching { return .loading }
            if let searchError { return .error(searchError) }
            if !items.isEmpty {
                let favoriteIDs = Set(favorites.map(\.id))
                return .loaded(items.map { repository in
                    RepositoryDisplayItem(repository: repository, isFavorite: favoriteIDs.contains(repository.id))
                })
            }
            // 検索が一度も実行されていない（初回起動など）間は .idle。.empty は「検索した結果 0 件」専用
            return lastSearchedQuery == nil ? .idle : .empty
        }

        var isSearchQueryBlank: Bool {
            searchQuery.trimmingCharacters(in: .whitespaces).isEmpty
        }
    }

    public enum Action: ViewAction {
        case destination(PresentationAction<Destination.Action>)
        case `internal`(Internal)
        case view(View)

        @CasePathable
        public enum Internal {
            /// 入力が 500ms 止まった
            case debounceCompleted
            case favoriteToggleFailed
            case favoritesResponse([FavoriteEntity])
            case historyResponse([String])
            case loadMoreFailed
            case loadMoreResponse(SearchResultEntity, page: Int)
            /// 画面表示時の読み込み（お気に入り・検索履歴）が終わった
            case loadResponse(favorites: [FavoriteEntity], history: [String])
            /// 検索が CancellationError で終わった（通信のキャンセルなど）
            case searchCancelled
            case searchFailed(message: String)
            case searchResponse(SearchResultEntity, favorites: [FavoriteEntity], history: [String])
        }

        @CasePathable
        public enum View: BindableAction {
            case binding(BindingAction<State>)
            case clearHistoryButtonTapped
            case favoriteButtonTapped(id: Int)
            case historyDeleteButtonTapped(String)
            case historyTapped(String)
            case refreshPulled
            case retryButtonTapped
            case rowAppeared(id: Int)
            case rowTapped(id: Int)
            case task
        }
    }

    enum CancelID {
        /// debounce の待機と 1 ページ目の検索（新しい入力・検索が前のものを置き換える）
        case search
        case loadMore
    }

    @Dependency(\.continuousClock) var clock
    @Dependency(\.favoriteClient) var favoriteClient
    @Dependency(\.searchClient) var searchClient
    @Dependency(\.searchHistoryClient) var searchHistoryClient

    public init() {}

    public var body: some ReducerOf<Self> {
        BindingReducer(action: \.view)
            .onChange(of: \.searchQuery) { _, state in
                searchQueryChanged(&state)
            }

        Reduce { state, action in
            switch action {
            case .view(.binding):
                return .none

            case .view(.task):
                return .run { send in
                    let favorites = await favoriteClient.refresh()
                    let history = await searchHistoryClient.history()
                    await send(.internal(.loadResponse(favorites: favorites, history: history)))
                }

            case .view(.refreshPulled), .view(.retryButtonTapped):
                guard !state.isSearchQueryBlank else { return .none }
                return performSearch(&state)

            case .view(.rowAppeared(let id)):
                // 末尾 3 件のいずれかが表示されたら次ページを読み込む
                guard state.items.suffix(3).contains(where: { $0.id == id }),
                      state.hasNextPage,
                      !state.isLoadingMore
                else { return .none }
                state.isLoadingMore = true
                return .run { [query = state.searchQuery, page = state.currentPage + 1] send in
                    do {
                        let result = try await searchClient.search(query, page)
                        await send(.internal(.loadMoreResponse(result, page: page)))
                    } catch {
                        await send(.internal(.loadMoreFailed))
                    }
                }
                .cancellable(id: CancelID.loadMore)

            case .view(.rowTapped(let id)):
                guard let repository = state.items.first(where: { $0.id == id }),
                      let url = makeGitHubURL(fullName: repository.fullName)
                else { return .none }
                state.destination = .safari(SafariDestination(url: url))
                return .none

            case .view(.favoriteButtonTapped(let id)):
                guard let repository = state.items.first(where: { $0.id == id }) else { return .none }
                return .run { [isFavorite = state.favorites.contains(where: { $0.id == id })] send in
                    do {
                        let favorites = if isFavorite {
                            try await favoriteClient.remove(id)
                        } else {
                            try await favoriteClient.add(repository)
                        }
                        await send(.internal(.favoritesResponse(favorites)))
                    } catch {
                        await send(.internal(.favoriteToggleFailed))
                    }
                }

            case .view(.historyTapped(let query)):
                // 履歴からの選択は debounce を待たずに即時検索する
                state.searchQuery = query
                return performSearch(&state)

            case .view(.historyDeleteButtonTapped(let query)):
                return .run { send in
                    await send(.internal(.historyResponse(await searchHistoryClient.remove(query))))
                }

            case .view(.clearHistoryButtonTapped):
                return .run { send in
                    await searchHistoryClient.clear()
                    await send(.internal(.historyResponse([])))
                }

            case .internal(.debounceCompleted):
                return searchIfNeeded(&state)

            case .internal(.loadResponse(let favorites, let history)):
                state.$favorites.withLock { $0 = favorites }
                state.history = history
                // タブ復帰などで画面が再表示されたとき、完了しなかった検索（キャンセル・失敗）をやり直す
                return searchIfNeeded(&state)

            case .internal(.searchResponse(let result, let favorites, let history)):
                state.items = result.items
                state.hasNextPage = result.hasNextPage
                state.$favorites.withLock { $0 = favorites }
                state.history = history
                state.isSearching = false
                state.searchError = nil
                return .none

            case .internal(.searchCancelled):
                // 完了していない検索は「検索済み」にしない（同じクエリで再検索できるように）
                state.lastSearchedQuery = nil
                return .none

            case .internal(.searchFailed(let message)):
                state.lastSearchedQuery = nil
                state.isSearching = false
                state.searchError = message
                return .none

            case .internal(.loadMoreResponse(let result, let page)):
                state.isLoadingMore = false
                state.currentPage = page
                state.items.append(contentsOf: result.items)
                state.hasNextPage = result.hasNextPage
                return .none

            case .internal(.loadMoreFailed):
                // ページ追加読み込み失敗は既存データを維持
                state.isLoadingMore = false
                return .none

            case .internal(.favoritesResponse(let favorites)):
                state.$favorites.withLock { $0 = favorites }
                return .none

            case .internal(.favoriteToggleFailed):
                state.destination = .alert(Self.favoriteUpdateFailedAlert)
                return .none

            case .internal(.historyResponse(let history)):
                state.history = history
                return .none

            case .destination:
                return .none
            }
        }
        .ifLet(\.$destination, action: \.destination)
    }

    /// 検索バーの入力が変わったときの処理。空クエリは即リセットし、それ以外は 500ms の無入力を待つ（debounce）
    private func searchQueryChanged(_ state: inout State) -> Effect<Action> {
        // 入力の変化は実行中の検索をキャンセルする。完了しなかった検索は「検索済み」にしない
        if state.isSearching {
            state.lastSearchedQuery = nil
        }
        guard !state.isSearchQueryBlank else {
            state.items = []
            state.currentPage = 1
            state.hasNextPage = false
            state.lastSearchedQuery = nil
            state.isSearching = false
            state.searchError = nil
            state.isLoadingMore = false
            return .merge(.cancel(id: CancelID.search), .cancel(id: CancelID.loadMore))
        }
        return .run { send in
            try await clock.sleep(for: .milliseconds(500))
            await send(.internal(.debounceCompleted))
        }
        .cancellable(id: CancelID.search, cancelInFlight: true)
    }

    /// 現在のクエリが未検索なら検索する。空クエリと、検索済み（または検索中）と同じクエリでは何もしない
    private func searchIfNeeded(_ state: inout State) -> Effect<Action> {
        guard !state.isSearchQueryBlank, state.searchQuery != state.lastSearchedQuery else { return .none }
        return performSearch(&state)
    }

    private func performSearch(_ state: inout State) -> Effect<Action> {
        state.isSearching = true
        state.searchError = nil
        state.currentPage = 1
        state.items = []
        state.isLoadingMore = false
        state.lastSearchedQuery = state.searchQuery

        return .merge(
            .cancel(id: CancelID.loadMore),
            .run { [query = state.searchQuery] send in
                Logger.search.info("Search started: query=\(query, privacy: .public), page=1")
                do {
                    let result = try await searchClient.search(query, 1)
                    // 検索中に入力が変わってキャンセルされていたら、お気に入りの再取得も履歴への追加も行わない
                    try Task.checkCancellation()
                    let favorites = await favoriteClient.refresh()
                    // 結果が 0 件でも「ユーザが意図して入力した検索語」であることに変わりはないので履歴に残す
                    let history = await searchHistoryClient.add(query)
                    Logger.search.info("Search succeeded: count=\(result.items.count), totalCount=\(result.totalCount), hasNextPage=\(result.hasNextPage)")
                    await send(.internal(.searchResponse(result, favorites: favorites, history: history)))
                } catch is CancellationError {
                    Logger.search.debug("Search cancelled: query=\(query, privacy: .public)")
                    await send(.internal(.searchCancelled))
                } catch {
                    Logger.search.error("Search failed: \(String(describing: error), privacy: .public)")
                    await send(.internal(.searchFailed(message: error.localizedDescription)))
                }
            }
            .cancellable(id: CancelID.search, cancelInFlight: true)
        )
    }

    static var favoriteUpdateFailedAlert: AlertState<Never> {
        AlertState {
            TextState("エラー", bundle: #bundle)
        } actions: {
            ButtonState { TextState("OK", bundle: #bundle) }
        } message: {
            TextState("お気に入りの更新に失敗しました", bundle: #bundle)
        }
    }
}

extension SearchFeature.Destination.State: Equatable {}
