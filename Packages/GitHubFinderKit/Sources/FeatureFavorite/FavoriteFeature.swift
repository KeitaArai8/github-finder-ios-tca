/*
 Abstract:
 お気に入り一覧画面の Reducer。
 通常表示モードと編集モード（複数選択→一括削除）を切り替える。
 ソート・言語フィルタはメモリ保持（永続化なし）。生データは `favorites` のまま保持し、`viewState` で表示順を導出する。
 */

import ComposableArchitecture
import Foundation
import os
import GitHubFinderDomain
import GitHubFinderData
import GitHubFinderDesignSystem

/// お気に入り一覧の並び替え基準
public enum FavoriteSortKey: String, CaseIterable, Identifiable, Sendable {
    case savedAtDesc      // 保存が新しい順（デフォルト）
    case starCountDesc    // ⭐ が多い順
    case fullNameAsc      // リポジトリ名 A→Z

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .savedAtDesc:   return String(localized: "新しい順", bundle: #bundle)
        case .starCountDesc: return String(localized: "Star が多い順", bundle: #bundle)
        case .fullNameAsc:   return String(localized: "名前順 (A→Z)", bundle: #bundle)
        }
    }
}

@Reducer
public struct FavoriteFeature: Sendable {
    @Reducer
    public enum Destination {
        @ReducerCaseIgnored
        case alert(AlertState<Never>)
        @ReducerCaseIgnored
        case confirmationDialog(ConfirmationDialogState<ConfirmationDialog>)
        @ReducerCaseIgnored
        case safari(SafariDestination)

        // Action を持つのは alert / confirmationDialog だけ。safari は表示データのみで Action を持たない
        @CasePathable
        public enum Action {
            case alert(Never)
            case confirmationDialog(ConfirmationDialog)
        }

        @CasePathable
        public enum ConfirmationDialog {
            /// 選択中のお気に入りの一括削除を確定した
            case confirmDeletion
        }
    }

    @ObservableState
    public struct State: Equatable {
        @Presents public var destination: Destination.State?
        /// 並び替え基準（メモリ保持。アプリ再起動でリセット）
        public var sortKey: FavoriteSortKey = .savedAtDesc

        /// お気に入り一覧（生データ）。検索画面と共有する（どちらの画面の変更も、もう一方へすぐ反映される）
        @Shared var favorites: [FavoriteEntity]
        /// 初回の読み込みを開始したか（開始前は .idle）
        var hasStartedLoading = false
        /// 初回の読み込みが完了したか（完了までは .loading）
        var hasLoaded = false
        var isEditModeRequested = false
        var storedSelectedIDs: Set<Int> = []
        var storedFilterLanguage: String?

        public init(favorites: Shared<[FavoriteEntity]>) {
            self._favorites = favorites
        }

        /// 画面のフェーズ。保存せず、読み込みの事実（`hasStartedLoading` / `hasLoaded`）と `favorites` から都度導出する
        public var viewState: ViewState<[FavoriteEntity]> {
            guard hasStartedLoading else { return .idle }
            guard hasLoaded else { return .loading }
            guard !favorites.isEmpty else { return .empty }
            return .loaded(sortedAndFilteredFavorites)
        }

        /// 編集モード（複数選択可能）中かどうか。お気に入りが 0 件のときは編集モードとして扱わない
        public var isEditMode: Bool {
            isEditModeRequested && !favorites.isEmpty
        }

        /// 編集モード中に選択されているお気に入りID。現在のお気に入りに存在しない ID は除く
        public var selectedIDs: Set<Int> {
            guard isEditMode else { return [] }
            return storedSelectedIDs.intersection(favorites.map(\.id))
        }

        /// 言語フィルタ（nil = フィルタ無し）。
        /// 現在のお気に入りに存在しない言語が指定されている場合は nil（フィルタ無し）として扱う
        public var filterLanguage: String? {
            guard let language = storedFilterLanguage,
                  favorites.contains(where: { $0.language == language }) else { return nil }
            return language
        }

        /// 言語フィルタの選択肢（生のお気に入りから抽出した重複なし、ソート済み）
        public var availableLanguages: [String] {
            Set(favorites.compactMap(\.language))
                .sorted { $0.localizedStandardCompare($1) == .orderedAscending }
        }

        /// 表示中（フィルタ後）のお気に入りすべてが選択済みかどうか。
        /// 「全選択 ⇔ 全解除」トグルボタンのラベル切り替えに使う。iOS Photos.app の defacto。
        public var isAllSelected: Bool {
            guard case .loaded(let items) = viewState, !items.isEmpty else { return false }
            return Set(items.map(\.id)) == selectedIDs
        }

        /// 編集モード TopBar 左に出すボタンのタイトル。
        /// View は状態を表示するだけの Passive View に保つため、条件による文言の出し分けは State が持つ。
        public var selectAllButtonTitle: String {
            isAllSelected ? String(localized: "全解除", bundle: #bundle) : String(localized: "全選択", bundle: #bundle)
        }

        /// 生のお気に入りに sortKey / filterLanguage を適用した表示用配列
        private var sortedAndFilteredFavorites: [FavoriteEntity] {
            let filtered: [FavoriteEntity]
            if let language = filterLanguage {
                filtered = favorites.filter { $0.language == language }
            } else {
                filtered = favorites
            }

            switch sortKey {
            case .savedAtDesc:
                return filtered.sorted { $0.savedAt > $1.savedAt }
            case .starCountDesc:
                return filtered.sorted { $0.starCount > $1.starCount }
            case .fullNameAsc:
                return filtered.sorted { $0.fullName.localizedStandardCompare($1.fullName) == .orderedAscending }
            }
        }

        /// お気に入りが変わったあとのイベント処理で、無効になった編集・フィルタ状態を実際に捨てる。
        /// 読み取り側（`isEditMode` / `selectedIDs` / `filterLanguage`）でも無効値は除くが、
        /// ここで捨てないと、お気に入りが再び増えたときに編集モードやフィルタが勝手に復活してしまう
        mutating func resetStaleSelectionState() {
            if favorites.isEmpty {
                isEditModeRequested = false
                storedSelectedIDs = []
            }
            if let language = storedFilterLanguage,
               !favorites.contains(where: { $0.language == language }) {
                storedFilterLanguage = nil
            }
        }
    }

    public enum Action: ViewAction {
        case destination(PresentationAction<Destination.Action>)
        case `internal`(Internal)
        case view(View)

        @CasePathable
        public enum Internal {
            /// 一括削除が最後まで成功した
            case bulkRemoveResponse([FavoriteEntity])
            case loadResponse([FavoriteEntity])
            /// 削除に失敗した。`latest` は失敗までに成功した削除を反映した一覧（1 件も成功していなければ nil）
            case removeFailed(latest: [FavoriteEntity]?)
            case removeResponse([FavoriteEntity])
        }

        @CasePathable
        public enum View {
            case deleteSelectedButtonTapped
            case doneButtonTapped
            case editButtonTapped
            /// 言語フィルタのチップがタップされた（nil は「すべて」）
            case filterChipTapped(String?)
            case refreshPulled
            case retryButtonTapped
            case rowTapped(id: Int)
            case rowsSwipeDeleted(ids: [Int])
            case selectAllButtonTapped
            case sortKeySelected(FavoriteSortKey)
            case task
        }
    }

    @Dependency(\.favoriteClient) var favoriteClient

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .view(.task), .view(.refreshPulled), .view(.retryButtonTapped):
                state.hasStartedLoading = true
                return .run { send in
                    await send(.internal(.loadResponse(await favoriteClient.refresh())))
                }

            case .view(.rowTapped(let id)):
                if state.isEditMode {
                    if state.storedSelectedIDs.contains(id) {
                        state.storedSelectedIDs.remove(id)
                    } else {
                        state.storedSelectedIDs.insert(id)
                    }
                } else if let favorite = state.favorites.first(where: { $0.id == id }),
                          let url = makeGitHubURL(fullName: favorite.fullName) {
                    state.destination = .safari(SafariDestination(url: url))
                }
                return .none

            case .view(.rowsSwipeDeleted(let ids)):
                return .run { send in
                    for id in ids {
                        do {
                            let favorites = try await favoriteClient.remove(id)
                            Logger.favorite.info("Favorite removed: id=\(id, privacy: .public)")
                            await send(.internal(.removeResponse(favorites)))
                        } catch {
                            Logger.favorite.error("Favorite remove failed: id=\(id, privacy: .public), error=\(error.localizedDescription, privacy: .public)")
                            await send(.internal(.removeFailed(latest: nil)))
                        }
                    }
                }

            case .view(.sortKeySelected(let sortKey)):
                state.sortKey = sortKey
                return .none

            case .view(.filterChipTapped(let language)):
                // 選択中のチップをもう一度タップすると選択解除（トグル動作）
                let newLanguage = language == state.filterLanguage ? nil : language
                // 現在のお気に入りに存在しない言語は受け付けない（フィルタ無しとして扱う）
                if let newLanguage, !state.favorites.contains(where: { $0.language == newLanguage }) {
                    state.storedFilterLanguage = nil
                } else {
                    state.storedFilterLanguage = newLanguage
                }
                return .none

            case .view(.editButtonTapped):
                guard case .loaded = state.viewState else { return .none }
                state.isEditModeRequested = true
                state.storedSelectedIDs = []
                return .none

            case .view(.doneButtonTapped):
                state.isEditModeRequested = false
                state.storedSelectedIDs = []
                return .none

            case .view(.selectAllButtonTapped):
                // 全選択 ⇔ 全解除のトグル。部分選択中は全選択にする
                if state.isAllSelected {
                    state.storedSelectedIDs = []
                } else if case .loaded(let items) = state.viewState {
                    state.storedSelectedIDs = Set(items.map(\.id))
                }
                return .none

            case .view(.deleteSelectedButtonTapped):
                let count = state.selectedIDs.count
                guard count > 0 else { return .none }
                state.destination = .confirmationDialog(Self.deleteConfirmationDialog(count: count))
                return .none

            case .destination(.presented(.confirmationDialog(.confirmDeletion))):
                // 削除順を固定するため ID 昇順で処理する
                let idsToRemove = state.selectedIDs.sorted()
                guard !idsToRemove.isEmpty else { return .none }
                return .run { send in
                    Logger.favorite.info("Bulk delete started: count=\(idsToRemove.count)")
                    var latest: [FavoriteEntity]?
                    do {
                        for id in idsToRemove {
                            latest = try await favoriteClient.remove(id)
                        }
                        Logger.favorite.info("Bulk delete succeeded: count=\(idsToRemove.count)")
                        await send(.internal(.bulkRemoveResponse(latest ?? [])))
                    } catch {
                        Logger.favorite.error("Bulk delete failed: error=\(error.localizedDescription, privacy: .public)")
                        await send(.internal(.removeFailed(latest: latest)))
                    }
                }

            case .internal(.loadResponse(let favorites)):
                state.$favorites.withLock { $0 = favorites }
                state.hasLoaded = true
                state.resetStaleSelectionState()
                return .none

            case .internal(.removeResponse(let favorites)):
                state.$favorites.withLock { $0 = favorites }
                state.resetStaleSelectionState()
                return .none

            case .internal(.bulkRemoveResponse(let favorites)):
                state.$favorites.withLock { $0 = favorites }
                state.storedSelectedIDs = []
                state.resetStaleSelectionState()
                return .none

            case .internal(.removeFailed(let latest)):
                if let latest {
                    state.$favorites.withLock { $0 = latest }
                }
                state.destination = .alert(Self.removeFailedAlert)
                return .none

            case .destination:
                return .none
            }
        }
        .ifLet(\.$destination, action: \.destination)
    }

    static var removeFailedAlert: AlertState<Never> {
        AlertState {
            TextState("エラー", bundle: #bundle)
        } actions: {
            ButtonState { TextState("OK", bundle: #bundle) }
        } message: {
            TextState("お気に入りの削除に失敗しました", bundle: #bundle)
        }
    }

    static func deleteConfirmationDialog(count: Int) -> ConfirmationDialogState<Destination.ConfirmationDialog> {
        ConfirmationDialogState(titleVisibility: .visible) {
            TextState("\(count)件のお気に入りを削除しますか？", bundle: #bundle)
        } actions: {
            ButtonState(role: .destructive, action: .confirmDeletion) {
                TextState("削除", bundle: #bundle)
            }
            ButtonState(role: .cancel) {
                TextState("キャンセル", bundle: #bundle)
            }
        } message: {
            TextState("この操作は取り消せません。", bundle: #bundle)
        }
    }
}

extension FavoriteFeature.Destination.State: Equatable {}
