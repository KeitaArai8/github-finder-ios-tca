/*
 Abstract:
 リポジトリ検索画面。キーワード入力、検索結果一覧、お気に入りトグルを提供。
 */

import SwiftUI
import ComposableArchitecture
import GitHubFinderDomain
import GitHubFinderData
import GitHubFinderDesignSystem

@ViewAction(for: SearchFeature.self)
public struct SearchView: View {
    @Bindable public var store: StoreOf<SearchFeature>

    /// 検索履歴行の削除（X）ボタンの一辺（pt）。アイコンの周囲にタップ領域を確保する。
    private static let historyDeleteButtonSide: CGFloat = 36

    public init(store: StoreOf<SearchFeature>) {
        self.store = store
    }

    public var body: some View {
        NavigationStack {
            contentView
                .navigationTitle(LocalizedStringResource("検索", bundle: #bundle))
                .searchable(
                    text: $store.searchQuery,
                    prompt: Text("リポジトリを検索", bundle: #bundle)
                )
                .task {
                    send(.task)
                }
                .alert($store.scope(\.$destination, action: \.destination).alert)
                .sheet(item: $store.scope(\.$destination, action: \.destination).safari) { destination in
                    SafariView(url: destination.url)
                }
        }
    }

    @ViewBuilder
    private var contentView: some View {
        switch store.viewState {
        case .idle:
            // 履歴がある場合は履歴一覧を、無ければ初期メッセージを表示
            if store.history.isEmpty {
                ContentUnavailableView(
                    label: { Label(LocalizedStringResource("リポジトリを検索", bundle: #bundle), systemImage: "magnifyingglass") },
                    description: { Text("キーワードを入力して\nGitHubリポジトリを探しましょう", bundle: #bundle) }
                )
            } else {
                searchHistoryList
            }

        case .loading:
            ProgressView { Text("検索中...", bundle: #bundle) }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

        case .loaded(let items):
            repositoryList(items)

        case .empty:
            ContentUnavailableView(
                label: { Label(LocalizedStringResource("結果が見つかりません", bundle: #bundle), systemImage: "magnifyingglass") },
                description: { Text("別のキーワードで検索してみてください", bundle: #bundle) }
            )

        case .error(let message):
            ErrorView(message: message) {
                send(.retryButtonTapped)
            }
        }
    }

    // MARK: - Search History

    private var searchHistoryList: some View {
        List {
            Section {
                ForEach(store.history, id: \.self) { query in
                    // 行タップで再検索 / 行末 X タップで個別削除（Android と統一）。
                    // swipeActions ではなく trailing X icon を採用しているのは、検索履歴の業界 defacto
                    // (Google / YouTube / Chrome 等) に従い、可視性と 1-tap 完結を優先するため。
                    //
                    // 構造: 「行タップ用 Button」と「X 削除 Button」を並列に配置し、
                    //       両方を `.buttonStyle(.plain)` で SwiftUI に「独立した tap 領域」と認識させる。
                    //       VoiceOver でも 2 つの操作要素として個別フォーカスされる。
                    HStack(spacing: 0) {
                        Button {
                            send(.historyTapped(query))
                        } label: {
                            HStack(spacing: Spacing.spacing150) {
                                Image(systemName: "clock.arrow.circlepath")
                                    .foregroundStyle(Color.Content.secondary)
                                Text(query)
                                    .foregroundStyle(Color.Content.primary)
                                Spacer(minLength: 0)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(query)
                        .accessibilityHint(Text("ダブルタップでこのキーワードを再検索", bundle: #bundle))

                        Button {
                            send(.historyDeleteButtonTapped(query))
                        } label: {
                            Image(systemName: "xmark")
                                .font(.appLabelMedium)
                                .foregroundStyle(Color.Content.tertiary)
                                .frame(width: Self.historyDeleteButtonSide, height: Self.historyDeleteButtonSide)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(Text("\(query) を履歴から削除", bundle: #bundle))
                    }
                }
            } header: {
                HStack {
                    Text("最近の検索", bundle: #bundle)
                    Spacer()
                    Button(LocalizedStringResource("すべて消去", bundle: #bundle), role: .destructive) {
                        send(.clearHistoryButtonTapped)
                    }
                    .font(.appLabelMedium)
                    .textCase(nil)
                }
            }
        }
        .listStyle(.plain)
    }

    private func repositoryList(_ items: [RepositoryDisplayItem]) -> some View {
        List {
            ForEach(items) { item in
                RepositoryRow(
                    item: item,
                    onOpen: { send(.rowTapped(id: item.id)) },
                    onFavoriteTap: { send(.favoriteButtonTapped(id: item.id)) }
                )
                .contextMenu {
                    if let url = makeGitHubURL(fullName: item.fullName) {
                        ShareLink(item: url) {
                            Label(LocalizedStringResource("リポジトリをシェア", bundle: #bundle), systemImage: "square.and.arrow.up")
                        }
                    }
                }
                .onAppear {
                    send(.rowAppeared(id: item.id))
                }
            }

            if store.isLoadingMore {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .listRowSeparator(.hidden)
            }
        }
        .listStyle(.plain)
        .refreshable {
            await send(.refreshPulled).finish()
        }
    }
}

// MARK: - Repository Row

private struct RepositoryRow: View {
    let item: RepositoryDisplayItem
    let onOpen: () -> Void
    let onFavoriteTap: () -> Void

    var body: some View {
        // 「リポジトリを開く Button」と「お気に入り Button」を並列に配置する（検索履歴行と同じ構造）。
        // 入れ子にせず独立した tap 領域にすることで、タップが衝突せず VoiceOver でも別々のボタンとして読まれる。
        HStack(alignment: .center, spacing: Spacing.spacing150) {
            Button(action: onOpen) {
                HStack(alignment: .center, spacing: Spacing.spacing150) {
                    RepositorySummaryView(
                        fullName: item.fullName,
                        description: item.description,
                        starCount: item.starCount,
                        language: item.language,
                        ownerAvatarURL: item.ownerAvatarURL
                    )
                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            favoriteButton
        }
        .padding(.vertical, Spacing.spacing50)
    }

    private var favoriteButton: some View {
        Button(action: onFavoriteTap) {
            Image(systemName: item.isFavorite ? "heart.fill" : "heart")
                .foregroundStyle(item.isFavorite ? Color.Brand.favorite : Color.Content.tertiary)
                .font(.title3)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(item.isFavorite
            ? Text("お気に入りから削除", bundle: #bundle, comment: "Accessibility label when the repository is currently a favorite")
            : Text("お気に入りに追加", bundle: #bundle, comment: "Accessibility label when the repository is not a favorite yet")
        )
        .accessibilityHint(Text("ダブルタップで切り替え", bundle: #bundle, comment: "Accessibility hint for favorite toggle"))
    }
}

// MARK: - Previews

#if DEBUG

/// Preview 用: 指定した State をそのまま表示する Store（Reducer を持たないため副作用は走らない）
@MainActor
private func makePreviewStore(_ configure: (inout SearchFeature.State) -> Void = { _ in }) -> StoreOf<SearchFeature> {
    var state = SearchFeature.State(favorites: Shared(value: []))
    configure(&state)
    return Store(initialState: state) {
        EmptyReducer()
    }
}

private func previewRepository(id: Int, fullName: String, star: Int, language: String? = "Swift") -> RepositoryEntity {
    RepositoryEntity(
        id: id,
        fullName: fullName,
        description: "Sample repository description",
        starCount: star,
        language: language,
        ownerAvatarURL: nil
    )
}

#Preview("Idle（初期状態・履歴なし）") {
    SearchView(store: makePreviewStore())
}

#Preview("Idle（履歴あり）") {
    SearchView(store: makePreviewStore {
        $0.history = ["swift", "compose", "kotlin", "tca", "jetpack"]
    })
}

#Preview("Loaded") {
    SearchView(store: makePreviewStore {
        $0.searchQuery = "preview"
        $0.lastSearchedQuery = "preview"
        $0.items = [
            previewRepository(id: 1, fullName: "apple/swift", star: 67_000, language: "C++"),
            previewRepository(id: 2, fullName: "pointfreeco/swift-composable-architecture", star: 13_000),
            previewRepository(id: 3, fullName: "Alamofire/Alamofire", star: 41_000),
        ]
    })
}

#Preview("Loading") {
    SearchView(store: makePreviewStore {
        $0.searchQuery = "preview"
        $0.isSearching = true
    })
}

#Preview("Empty") {
    SearchView(store: makePreviewStore {
        $0.searchQuery = "preview"
        $0.lastSearchedQuery = "preview"
    })
}

#Preview("Error") {
    SearchView(store: makePreviewStore {
        $0.searchQuery = "preview"
        $0.searchError = "ネットワークに接続できません"
    })
}

#endif
