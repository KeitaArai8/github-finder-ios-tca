/*
 Abstract:
 お気に入りリポジトリの一覧画面。
 通常モード: スワイプ削除 / 行タップでGitHubページを開く
 編集モード: 複数選択 → 一括削除（確認ダイアログ付き）
 */

import SwiftUI
import ComposableArchitecture
import GitHubFinderDomain
import GitHubFinderData
import GitHubFinderDesignSystem

@ViewAction(for: FavoriteFeature.self)
public struct FavoriteListView: View {
    @Bindable public var store: StoreOf<FavoriteFeature>

    public init(store: StoreOf<FavoriteFeature>) {
        self.store = store
    }

    public var body: some View {
        let destinationBinding = $store.scope(\.$destination, action: \.destination)
        NavigationStack {
            contentView
                .navigationTitle(navigationTitle)
                .toolbar { toolbarContent }
                .task {
                    send(.task)
                }
                .alert(destinationBinding.alert)
                .confirmationDialog(destinationBinding.confirmationDialog)
                .sheet(item: destinationBinding.safari) { destination in
                    SafariView(url: destination.url)
                }
        }
    }

    private var navigationTitle: LocalizedStringResource {
        store.isEditMode ? LocalizedStringResource("\(store.selectedIDs.count)件選択", bundle: #bundle) : LocalizedStringResource("お気に入り", bundle: #bundle)
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        // 通常モード時: 右 = ソートメニュー + 編集ボタン（Android と並び順を統一）
        // 編集モード時: 左 = 全選択 / 右 = 削除(N) + 完了
        // ※ Android 側と同じく TopBar に集約。bottomBar は TabView 内の NavigationStack だと
        //   タブバーと衝突して表示されない SwiftUI の挙動があるため避けて TopBar に統一する。
        if case .loaded = store.viewState {
            if store.isEditMode {
                editModeToolbarContent
            } else {
                normalModeToolbarContent
            }
        }
    }

    @ToolbarContentBuilder
    private var normalModeToolbarContent: some ToolbarContent {
        // [sortMenu | 編集] の並び（Android の actions と同一順）。
        // 別々の ToolbarItem + 固定スペーサーにして、iOS 26 の Liquid Glass 上で
        // 「ソート」と「編集」を別のグラスとして分ける（同一グループだと 1 枚に融合する）。
        ToolbarItem(placement: .topBarTrailing) {
            sortMenu
        }
        ToolbarSpacer(.fixed, placement: .topBarTrailing)
        ToolbarItem(placement: .topBarTrailing) {
            Button(LocalizedStringResource("編集", bundle: #bundle)) {
                send(.editButtonTapped)
            }
        }
    }

    @ToolbarContentBuilder
    private var editModeToolbarContent: some ToolbarContent {
        // 全選択 ⇔ 全解除トグルを左に配置（iOS Photos.app と同じパターン）。
        // ラベル文言・状態判定は State に集約しているため、View 側に if/三項演算子は書かない。
        ToolbarItem(placement: .topBarLeading) {
            Button(store.selectAllButtonTitle) {
                send(.selectAllButtonTapped)
            }
        }
        // 削除(N) と 完了 は右に並べ、固定スペーサーで別のグラスに分ける。
        // 完了は確定操作なので role: .confirm（システムが強調スタイルで描く）。
        ToolbarItem(placement: .topBarTrailing) {
            Button(role: .destructive) {
                send(.deleteSelectedButtonTapped)
            } label: {
                Text("削除(\(store.selectedIDs.count))", bundle: #bundle)
            }
            .disabled(store.selectedIDs.isEmpty)
        }
        ToolbarSpacer(.fixed, placement: .topBarTrailing)
        ToolbarItem(placement: .topBarTrailing) {
            Button(LocalizedStringResource("完了", bundle: #bundle), role: .confirm) {
                send(.doneButtonTapped)
            }
        }
    }

    private var sortMenu: some View {
        Menu {
            Picker(LocalizedStringResource("並び替え", bundle: #bundle), selection: Binding(
                get: { store.sortKey },
                set: { send(.sortKeySelected($0)) }
            )) {
                ForEach(FavoriteSortKey.allCases) { key in
                    Text(key.displayName).tag(key)
                }
            }
        } label: {
            Image(systemName: "arrow.up.arrow.down")
                .accessibilityLabel(Text("並び替え", bundle: #bundle))
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var contentView: some View {
        switch store.viewState {
        case .idle, .loading:
            ProgressView { Text("読み込み中...", bundle: #bundle) }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

        case .loaded(let favorites):
            favoriteList(favorites)

        case .empty:
            ContentUnavailableView(
                label: { Label(LocalizedStringResource("お気に入りがありません", bundle: #bundle), systemImage: "heart.slash") },
                description: { Text("検索画面からリポジトリを\nお気に入りに追加しましょう", bundle: #bundle) }
            )

        case .error(let message):
            ErrorView(message: message) {
                send(.retryButtonTapped)
            }
        }
    }

    private func favoriteList(_ favorites: [FavoriteEntity]) -> some View {
        // selectedIDs は読むたびに導出されるため、行ごとに読まず 1 回だけ読む
        let selectedIDs = store.selectedIDs
        return VStack(spacing: 0) {
            // 編集モード中はフィルタ操作も誤動作しがちなので非表示
            if !store.isEditMode {
                languageFilterBar
            }
            List {
                ForEach(favorites) { favorite in
                    Button {
                        send(.rowTapped(id: favorite.id))
                    } label: {
                        FavoriteRow(
                            favorite: favorite,
                            isEditMode: store.isEditMode,
                            isSelected: selectedIDs.contains(favorite.id)
                        )
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    // 通常モード時のみシェア可能（編集モード中は contextMenu 衝突回避）
                    .modifier(FavoriteRowShareModifier(
                        favorite: favorite,
                        isEditMode: store.isEditMode
                    ))
                }
                .onDelete(perform: store.isEditMode ? nil : { indexSet in
                    send(.rowsSwipeDeleted(ids: indexSet.map { favorites[$0].id }))
                })
            }
            .listStyle(.plain)
            .refreshable {
                await send(.refreshPulled).finish()
            }
            .overlay {
                // フィルタ後に該当0件の場合のメッセージ
                if favorites.isEmpty {
                    ContentUnavailableView(
                        label: { Label(LocalizedStringResource("該当するリポジトリがありません", bundle: #bundle), systemImage: "line.3.horizontal.decrease.circle") },
                        description: { Text("フィルタを変更してください", bundle: #bundle) }
                    )
                }
            }
        }
    }

    @ViewBuilder
    private var languageFilterBar: some View {
        let languages = store.availableLanguages
        // filterLanguage は読むたびに導出されるため、チップごとに読まず 1 回だけ読む
        let filterLanguage = store.filterLanguage
        if !languages.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Spacing.spacing100) {
                    FilterChip(
                        label: Text("すべて", bundle: #bundle),
                        isSelected: filterLanguage == nil,
                        action: { send(.filterChipTapped(nil)) }
                    )
                    ForEach(languages, id: \.self) { language in
                        FilterChip(
                            label: Text(verbatim: language),
                            isSelected: filterLanguage == language,
                            action: { send(.filterChipTapped(language)) }
                        )
                    }
                }
                .padding(.horizontal, Spacing.spacing200)
                .padding(.vertical, Spacing.spacing100)
            }
            .background(Color.Background.primary)
        }
    }
}

// MARK: - Filter Chip

private struct FilterChip: View {
    /// 固定文言（カタログで翻訳）と言語名（翻訳しない）を同じ型で受けるため `Text` で受け取る。
    let label: Text
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            label
                .font(.appBodyMedium)
                .padding(.horizontal, Spacing.spacing150)
                .padding(.vertical, Spacing.spacing50 + 2) // 6pt: 50 と 100 の中間
                .background(
                    Capsule()
                        .fill(isSelected ? Color.Content.accent : Color.Border.subtle)
                )
                .foregroundStyle(isSelected ? Color.Content.inverse : Color.Content.primary)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// MARK: - Share Modifier

/// 行に GitHub URL のシェアを提供する Menu/contextMenu を付与する。
/// 編集モード中は誤操作防止のため何も付けない。
private struct FavoriteRowShareModifier: ViewModifier {
    let favorite: FavoriteEntity
    let isEditMode: Bool

    func body(content: Content) -> some View {
        if isEditMode {
            content
        } else {
            content
                .contextMenu {
                    if let url = makeGitHubURL(fullName: favorite.fullName) {
                        ShareLink(item: url) {
                            Label(LocalizedStringResource("リポジトリをシェア", bundle: #bundle), systemImage: "square.and.arrow.up")
                        }
                    }
                }
                .swipeActions(edge: .leading, allowsFullSwipe: false) {
                    if let url = makeGitHubURL(fullName: favorite.fullName) {
                        ShareLink(item: url) {
                            Label(LocalizedStringResource("シェア", bundle: #bundle), systemImage: "square.and.arrow.up")
                        }
                        .tint(Color.Content.accent)
                    }
                }
        }
    }
}

// MARK: - Favorite Row

private struct FavoriteRow: View {
    let favorite: FavoriteEntity
    let isEditMode: Bool
    let isSelected: Bool

    var body: some View {
        HStack(alignment: .center, spacing: Spacing.spacing150) {
            if isEditMode {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? Color.Content.accent : Color.Content.tertiary)
                    .accessibilityLabel(isSelected ? Text("選択済み", bundle: #bundle) : Text("未選択", bundle: #bundle))
            }
            RepositorySummaryView(
                fullName: favorite.fullName,
                description: favorite.description,
                starCount: favorite.starCount,
                language: favorite.language,
                ownerAvatarURL: favorite.ownerAvatarURL
            )
        }
        .padding(.vertical, Spacing.spacing50)
        .accessibilityElement(children: .combine)
        .accessibilityHint(isEditMode
            ? Text("ダブルタップで選択/解除", bundle: #bundle)
            : Text("ダブルタップで GitHub ページを開く", bundle: #bundle)
        )
    }
}

// MARK: - Previews

#if DEBUG

/// Preview 用: 指定した State をそのまま表示する Store（Reducer を持たないため副作用は走らない）
@MainActor
private func makePreviewStore(_ configure: (inout FavoriteFeature.State) -> Void = { _ in }) -> StoreOf<FavoriteFeature> {
    var state = FavoriteFeature.State(favorites: Shared(value: []))
    state.hasStartedLoading = true
    state.hasLoaded = true
    configure(&state)
    return Store(initialState: state) {
        EmptyReducer()
    }
}

private func previewFavorites() -> [FavoriteEntity] {
    [
        FavoriteEntity(
            id: 1,
            fullName: "apple/swift",
            description: "The Swift Programming Language",
            starCount: 67_000,
            language: "C++",
            ownerAvatarURL: nil,
            savedAt: .now
        ),
        FavoriteEntity(
            id: 2,
            fullName: "pointfreeco/swift-composable-architecture",
            description: "A library for building applications in a consistent and understandable way",
            starCount: 13_000,
            language: "Swift",
            ownerAvatarURL: nil,
            savedAt: .now
        ),
        FavoriteEntity(
            id: 3,
            fullName: "Alamofire/Alamofire",
            description: "Elegant HTTP Networking",
            starCount: 41_000,
            language: "Swift",
            ownerAvatarURL: nil,
            savedAt: .now
        ),
    ]
}

#Preview("Loaded") {
    FavoriteListView(store: makePreviewStore {
        $0.$favorites.withLock { $0 = previewFavorites() }
    })
}

#Preview("Edit Mode（2件選択中）") {
    FavoriteListView(store: makePreviewStore {
        $0.$favorites.withLock { $0 = previewFavorites() }
        $0.isEditModeRequested = true
        $0.storedSelectedIDs = [1, 2]
    })
}

#Preview("Empty") {
    FavoriteListView(store: makePreviewStore())
}

#Preview("Loading") {
    FavoriteListView(store: makePreviewStore {
        $0.hasLoaded = false
    })
}

#endif
