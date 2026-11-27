# GitHubFinder (iOS / TCA 版)

GitHubのリポジトリをキーワードで検索し、お気に入りに保存できるiOSアプリです。[KeitaArai8/github-finder-ios](https://github.com/KeitaArai8/github-finder-ios)（SwiftUI + `@Observable` 版）と同じ機能・同じターゲット構成のまま、プレゼンテーション層を [The Composable Architecture（TCA）](https://github.com/pointfreeco/swift-composable-architecture) で組み直した学習サンプル実装です（SwiftUI + TCA + SwiftData + Swift Testing + WidgetKit）。

### TCA のバージョンについて

- TCA 2.0 は未リリースのため、**1.26.2** を使い、2.0 で廃止される API を警告にするパッケージ trait `ComposableArchitecture2Deprecations` を有効にしています（[`Package.swift`](Packages/GitHubFinderKit/Package.swift)）。
- この trait を有効にした状態で、TCA 由来の非推奨警告が 0 件になる書き方（`scope(_:action:)`、enum スコープ + `@ReducerCaseIgnored`、`inout State` を受け取る `onChange(of:)` など）に揃えています。移行内容は公式の [Migrating to 1.25](https://swiftpackageindex.com/pointfreeco/swift-composable-architecture/main/documentation/composablearchitecture/migratingto1.25) を参照してください。

## 技術スタック

| 項目 | 選定 |
|------|------|
| UI | SwiftUI |
| 状態管理 | The Composable Architecture 1.26.2（`@Reducer` + `@ObservableState`） |
| 永続化 | SwiftData（App Group 共有コンテナ） |
| ネットワーク | URLSession (async/await) |
| DI | swift-dependencies（`@DependencyClient` + `@Dependency`） |
| テスト | Swift Testing（`TestStore`）+ XCUITest |
| Widget | WidgetKit + TimelineProvider |
| 最小OS | iOS 26+ |
| Swift | Swift 6 言語モード（Xcode 27 / Swift 6.4） |

## アーキテクチャ

[Android公式アーキテクチャガイド](https://developer.android.com/topic/architecture)の設計思想を共通基盤とし、iOS のフレームワークで実現しています。

### 設計原則

| 原則 | 説明 |
|------|------|
| **UDF** | データは Data→UI へ流れ、イベントは UI→Data へ流れる |
| **SSOT** | お気に入り→SwiftData、検索結果→API+メモリキャッシュ |
| **不変データの公開** | Reducer のみが State を更新（View は `store.send` でイベントを送るだけ） |
| **関心の分離** | View は表示のみ、ロジックは Reducer に集約 |
| **テスタビリティ** | 依存クライアント（`@DependencyClient`）を `withDependencies` で差し替え、`TestStore` で状態遷移を網羅的に検証 |

### レイヤー構成

```
┌─────────────────────────────────┐
│         UI Layer                │
│  View (SwiftUI) ← 表示のみ      │
│  Reducer (@Reducer) ← UDF      │
└──────────────┬──────────────────┘
               ↓ @Dependency
┌─────────────────────────────────┐
│         Data Layer              │
│  DependencyClient ← Store /     │
│    Repository の薄いラッパー     │
│  Repository ← DataSource統合    │
│  ├── RemoteDataSource (API)     │
│  ├── LocalDataSource (SwiftData)│
│  └── CacheDataSource (メモリ)   │
└─────────────────────────────────┘
```

Domain Layer（UseCase）は設けていません。このアプリの規模では不要と判断しました（Android公式でもオプションと明記）。

### DataSource の分離

Android公式に従い、各DataSourceは**単一のデータソースのみ**を処理します。

| DataSource | 責務 | データソース |
|-----------|------|------------|
| `GitHubRemoteDataSource` | GitHub API 通信のみ（struct） | URLSession |
| `FavoriteLocalDataSource` | お気に入り CRUD のみ | SwiftData (`@ModelActor`, async throws) |
| `SearchCacheDataSource` | 検索結果のメモリキャッシュ | Dictionary (actor) |
| `TutorialLocalDataSource` | チュートリアルフラグ管理 | UserDefaults |

Repository が複数の DataSource を統合し、エラー変換やキャッシュ制御を行います。

### SSOT（単一信頼源）

| データ | SSOT | 理由 |
|--------|------|------|
| お気に入り | SwiftData (App Group 共有) | アプリ終了後も保持。アプリと Widget で同じファイルを参照 |
| 検索結果 | API + メモリキャッシュ | API が正。キャッシュはアプリ起動中のみ |
| チュートリアル表示済み | UserDefaults | ローカルフラグ |

### お気に入り設計（Passive View + SSOT）

Entity にフラグを持たせず、State の計算プロパティで表示用構造体 `RepositoryDisplayItem` に変換して公開します。View は受け取った値をそのまま表示するだけです。

```
SearchFeature.State（内部）
├── items: [RepositoryEntity]              ← API から取得した生データ
└── @Shared favorites: [FavoriteEntity]    ← お気に入り画面と共有するお気に入り一覧

SearchFeature.State（公開）
└── viewState: ViewState<[RepositoryDisplayItem]>  ← 上の 2 つを突き合わせて導出。View はこれを表示するだけ
```

お気に入りの SSOT は SwiftData（`FavoriteStore` 経由）のままです。画面上の一覧は、ルートの `AppFeature.State` が作る 1 つの共有 State（`Shared<[FavoriteEntity]>`）を検索画面とお気に入り画面の両方が `@Shared` で参照します。`FavoriteClient` の `refresh` / `add` / `remove` が返す操作後の一覧を Reducer が `state.$favorites.withLock { ... }` で書き込むため、片方のタブでの変更はもう一方のタブへ再読み込みなしで反映されます。

### エラーハンドリング

```
DataSource → 生の例外を throw
    ↓
Repository → catch して AppError に変換
    ↓
Reducer → AppError を State に保存（ViewState.error として導出）
    ↓
View → エラーメッセージ + リトライボタン表示
```

### ViewState（5状態）

| 状態 | 意味 |
|------|------|
| `idle` | 初期状態 |
| `loading` | データ取得中 |
| `loaded(data)` | データあり |
| `empty` | 取得成功だがデータなし |
| `error(message)` | 失敗 |

### DesignSystem トークン

`GitHubFinderDesignSystem` は単なる UI コンポーネント置き場ではなく、**セマンティック・トークン**を提供する真のデザインシステム。各 View はハードコードされた `16` / `Color.gray` / `.font(.headline)` を直接使わず、**必ずトークンを経由**する。

| トークン | 場所 | 例 |
|---------|------|-----|
| `Spacing` | `Tokens/Spacing.swift` | `Spacing.spacing100` (8pt), `Spacing.spacing200` (16pt) ... 8pt グリッドベース |
| `Radius` | `Tokens/Radius.swift` | `Radius.radius50` (4pt), `Radius.radius100` (8pt), `Radius.radiusFull` |
| `Color` | `Tokens/AppColor.swift` | `Color.Background.primary`, `Color.Content.secondary`, `Color.Brand.favorite` 等のセマンティック分類 |
| `Font` | `Tokens/AppFont.swift` | `.appTitleSmall`, `.appBodyMedium`, `.appLabelMedium`（Dynamic Type 追従） |

```swift
// ❌ ハードコード
HStack(spacing: 12) {
    Image(systemName: "heart.fill").foregroundStyle(.red)
    Text("お気に入り").font(.subheadline)
}
.padding(.horizontal, 16)
.background(Color(.systemBackground))

// ✅ トークン経由
HStack(spacing: Spacing.spacing150) {
    Image(systemName: "heart.fill").foregroundStyle(Color.Brand.favorite)
    Text("お気に入り").font(.appBodyMedium)
}
.padding(.horizontal, Spacing.spacing200)
.background(Color.Background.primary)
```

**メリット**:
- デザイン変更（spacing 体系の変更、ブランドカラー変更等）を**一箇所で吸収**できる
- トークン名が役割（intent）を表すため、コードを読むだけで設計意図がわかる
- ダークモード対応はセマンティックカラーが自動でハンドリング
- Dynamic Type にも自動追従

**確認**: `DesignSystemCatalog` ターゲットを起動すると、Tokens セクション（Spacing / Radius / AppColor / AppFont）でビジュアル一覧 + 実サイズが確認できる。

### App Group 共有コンテナ

アプリ本体と Widget Extension が SwiftData を共有するため、App Group 配下の SQLite ファイルを両ターゲットから参照します。

```swift
AppGroupContainer.makeModelContainer() throws -> ModelContainer
  → FileManager.containerURL(forSecurityApplicationGroupIdentifier:)
  → ModelConfiguration(url: storeURL)
```

失敗時の扱い:
- アプリ本体: `fatalError` で明確な診断（開発時の設定不備を即座に検知）
- Widget: `try?` で空状態にフォールバック（クラッシュ防止）

### オフライン検知（NetworkMonitor）

`NWPathMonitor` をラップした `@Observable` クラス `NetworkMonitor` を、`NetworkClient.connectivity`（接続状態の `AsyncStream<Bool>`）として Reducer へ公開しています。ルートの `AppFeature` が `.task` でストリームを購読し、`State.isConnected` を更新します（View の消滅で Effect がキャンセルされ、監視も止まります）。

```swift
case .view(.task):
    return .run { send in
        for await isConnected in await networkClient.connectivity() {
            await send(.internal(.connectivityChanged(isConnected)))
        }
    }
```

`AppRootView` はメイン画面の `safeAreaBar(edge: .top)` にバナーを差し込み、SwiftUI のトランジションで切り替えます:

```swift
if !store.isConnected {
    OfflineBanner()
        .transition(.move(edge: .top).combined(with: .opacity))
}
```

### 構造化ログ（os.Logger）

`subsystem = "com.example.GitHubFinder"` + 機能別 category で分類:

| Category | 用途 |
|---|---|
| `search` | 検索 / API 呼び出し |
| `favorite` | お気に入り CRUD |
| `network` | 接続状態変化 |

```swift
Logger.search.info("Search succeeded: count=\(count), totalCount=\(total)")
Logger.search.error("Search failed: \(error.localizedDescription, privacy: .public)")
```

**Console.app** から `subsystem == "com.example.GitHubFinder"` でフィルタ表示可能。

### 検索の debounce（`clock.sleep` + `cancellable`）

`SearchFeature` は `BindingReducer` に付けた `onChange(of: \.searchQuery)` で入力の変化を受け取り、`clock.sleep(for: .milliseconds(500))` の後に検索を始める Effect を `.cancellable(id:cancelInFlight: true)` で返す（空クエリは待たずに即リセット）。入力が変わると前の待機・実行中の検索がキャンセルされる。時間は `@Dependency(\.continuousClock)` 経由なので、テストでは `TestClock` を進めるだけで実時間を待たない。

## ディレクトリ構成（NiA 風モジュール分割）

Now in Android（NiA）に倣い、ローカル Swift Package `GitHubFinderKit` で物理的にレイヤー分割している。
App ターゲットはルートの Reducer と画面の組み立てのみ（4 ファイル）に保ち、各画面のロジック・UI はすべてパッケージ側に集約。
Feature 同士は直接参照不可で、コンパイル時に依存方向の不正を検出できる。

```
GitHubFinder/
├── GitHubFinder.xcodeproj
├── GitHubFinder/                              ← App ターゲット（ルート Reducer と画面の組み立てのみ）
│   ├── GitHubFinderApp.swift                  ← @main + ルート Store の生成
│   └── Presentation/App/
│       ├── AppFeature.swift                   ← ルート Reducer（3 タブ + チュートリアル + 接続状態）
│       ├── AppRootView.swift                  ← Tutorial/MainTabView + OfflineBanner 切替
│       └── MainTabView.swift                  ← 検索/お気に入り/設定の 3 タブ
│
├── FavoriteWidget/                            ← Widget Extension（別ターゲット）
│   ├── FavoriteWidget.swift                   ← TimelineProvider + WidgetView
│   ├── FavoriteWidgetBundle.swift
│   └── Localizable.xcstrings
│
├── DesignSystemCatalog/                       ← DesignSystem のカタログアプリ（別ターゲット）
├── GitHubFinderTests/                         ← Swift Testing の単体テスト
├── GitHubFinderUITests/                       ← XCUITest
│
└── Packages/GitHubFinderKit/                  ← Local Swift Package（7 target。外部依存は TCA と swift-dependencies）
    ├── Package.swift
    └── Sources/
        ├── GitHubFinderDomain/                ← Entity / Repository protocol / AppError / AppLogger
        │                                        （依存なし。全 target が transitively 依存）
        ├── GitHubFinderData/                  ← Repository Impl / DataSource (Remote/Local/Cache)
        │                                        DTO / DB / NetworkMonitor / FavoriteStore /
        │                                        SearchHistoryStore + Protocol / AppGroupContainer /
        │                                        Client（FavoriteClient / SearchClient /
        │                                        SearchHistoryClient / NetworkClient）
        │                                        （依存: Domain, swift-dependencies）
        ├── GitHubFinderDesignSystem/          ← Tokens (Spacing / Radius / AppColor / AppFont) /
        │                                        ViewState / ErrorView / OfflineBanner /
        │                                        RepositoryDisplayItem / GitHubURL /
        │                                        SafariView（依存: Domain）
        ├── FeatureSearch/                     ← SearchFeature + SearchView
        │                                        （依存: Domain, Data, DesignSystem, TCA）
        ├── FeatureFavorite/                   ← FavoriteFeature + FavoriteListView
        │                                        （依存: Domain, Data, DesignSystem, TCA）
        ├── FeatureSettings/                   ← SettingsFeature + SettingsView
        │                                        （依存: DesignSystem, TCA）
        └── FeatureTutorial/                   ← TutorialFeature / TutorialClient / CoachMarkOverlay /
                                                 CoachMarkPreferenceKey / TutorialScreen /
                                                 PulseEffect / View+ReverseMask /
                                                 TutorialLocalDataSource（依存: DesignSystem, TCA）
```

### モジュール依存グラフ

```
                    Domain (entities, protocols, errors, logger)
                       ▲
              ┌────────┴────────┐
              │                 │
            Data            DesignSystem
              ▲                 ▲
              │                 │
   ┌──────────┼──────┬──────────┼─────────┐
   │          │      │          │         │
FeatureSearch FeatureFavorite FeatureSettings FeatureTutorial
   │          │      │          │         │
   └──────────┴──────┴──────────┴─────────┘
                       │
                  App target
        （ルート Reducer + 画面の組み立て）
```

Feature target と App ターゲットは TCA（`ComposableArchitecture`）に依存します。`GitHubFinderData` は Widget と共有するため TCA 本体には依存させず、依存クライアントの定義に必要な `swift-dependencies`（`Dependencies` / `DependenciesMacros`）だけに依存します。Widget のコードは TCA を使いません。

| ターゲット | 依存先 |
|---|---|
| `GitHubFinder.app` | Data, DesignSystem, FeatureSearch, FeatureFavorite, FeatureSettings, FeatureTutorial |
| `FavoriteWidgetExtension.appex` | Domain, Data |
| `GitHubFinderTests` | 直接リンクなし（ホストアプリ `GitHubFinder.app` 経由で各モジュールを参照。TCA の二重リンクを避けるため） |

## DI の流れ

Reducer は外の世界（API・DB・UserDefaults・ネットワーク監視・時計）へ `@Dependency` 経由でのみアクセスします。依存クライアントは既存の Store / Repository の薄いラッパーで、本番実装は各クライアントの `liveValue` が組み立てます。

| クライアント | 使う Reducer | 本番実装（`liveValue`）が包むもの |
|---|---|---|
| `FavoriteClient` | `SearchFeature`, `FavoriteFeature` | `FavoriteStore` → `FavoriteRepositoryImpl` → `FavoriteLocalDataSource`（App Group の `ModelContainer`） |
| `SearchClient` | `SearchFeature` | `SearchRepositoryImpl(remote:, cache:)` |
| `SearchHistoryClient` | `SearchFeature` | `SearchHistoryStore`（UserDefaults） |
| `NetworkClient` | `AppFeature` | `NetworkMonitor`（`NWPathMonitor`） |
| `TutorialClient` | `AppFeature`, `TutorialFeature` | `TutorialLocalDataSource`（UserDefaults） |

```
GitHubFinderApp
└── Store(initialState: AppFeature.State()) { AppFeature() }
    ├── Scope → SearchFeature      ← searchClient / favoriteClient / searchHistoryClient / continuousClock
    ├── Scope → FavoriteFeature    ← favoriteClient
    ├── Scope → SettingsFeature
    └── ifLet → TutorialFeature    ← tutorialClient
```

## 機能一覧

### メイン機能

| 機能 | 説明 |
|------|------|
| キーワード検索 | デバウンス付き（500ms）、GitHub API |
| **検索履歴** | 直近10件を `UserDefaults` に永続化、Idle 時に履歴一覧 / 行タップで即時再検索 / 個別 swipe 削除 / 全消去 |
| 無限スクロール | ページネーション対応（末尾3件手前でプリフェッチ） |
| お気に入り登録/解除 | ハートボタン、SwiftData 永続化 |
| お気に入り一覧 | スワイプ削除 / 行タップで GitHub ページを SafariView で開く |
| **ソート（メモリ保持）** | 保存が新しい順 / Star 多い順 / 名前 A→Z（ToolbarItem の Menu Picker） |
| **言語フィルタ（メモリ保持）** | 登録済み言語を Chip で動的提示、トグルで絞り込み・解除（フィルタ中の言語が消失すると自動クリア） |
| **シェア** | `ShareLink`（iOS 16+）で GitHub URL をシェア（検索結果は contextMenu、お気に入りは contextMenu + leading swipe action） |
| **一括選択削除** | 編集モードで複数選択 → 確認ダイアログ → 一括削除 |
| メモリキャッシュ | 検索結果をアプリ起動中キャッシュ |
| プルリフレッシュ | 検索・お気に入り両画面 |
| **オフライン検知** | `NWPathMonitor` で接続状態を監視、切断時に画面上部にバナー表示 |
| **構造化ログ** | `os.Logger` で subsystem + category 別にイベントを記録（Console.app から検索可） |
| チュートリアル | **スポットライト型専用画面**（TutorialScreen）、初回起動時のみ |
| 設定画面 | プライバシーポリシー/利用規約（SFSafariViewController） |
| ダークモード | システム設定追従 |
| エラーハンドリング | 5分類（Network/RateLimit/Server/Decode/Unknown）+ リトライ |

### ホームウィジェット

| 項目 | 内容 |
|------|------|
| 機能 | お気に入り上位5件をホーム画面に表示 |
| サイズ | Small (1件) / Medium (3件) / Large (5件) |
| データ取得 | App Group 経由で SwiftData を直接読む |
| 更新頻度 | 1時間ごと（TimelineProvider .after policy） |
| タップ動作 | アプリ起動 |

### チュートリアル（スポットライト型）

専用の `TutorialScreen` でモック UI を組み、実際のアプリ UI と同じレイアウトに `coachMarkAnchor` を付与してスポットライトを当てます。本機能実装には一切影響しません。

| ステップ | 操作 |
|---------|------|
| 1. 検索バー | モック TextField タップで次へ |
| 2. お気に入りボタン | モックハートタップで次へ |
| 3. お気に入りタブ | モックタブタップで完了 |

## セキュリティ

| 項目 | 対応 |
|------|------|
| ATS | デフォルト有効（HTTPS 強制） |
| URL 構築 | `URLComponents` で path を自動 percent-encode（[GitHubURL.swift](Packages/GitHubFinderKit/Sources/GitHubFinderDesignSystem/GitHubURL.swift)） |
| App Group | メインアプリ・Widget 両方で `group.com.example.GitHubFinder` を設定 |
| データ保護 | 公開リポジトリ情報のみ保存。認証情報なし |
| SQL インジェクション | SwiftData Predicate（`#Predicate` マクロ）で型安全 |

## テスト

### Unit Tests（Swift Testing）

| 層 | テストファイル |
|---|---|
| App | AppFeatureTests |
| Presentation | SearchFeatureTests, FavoriteFeatureTests, SettingsFeatureTests, TutorialFeatureTests, SearchHistoryStoreTests |
| Data/Store | FavoriteStoreTests |
| Data/Cache | SearchCacheDataSourceTests |
| Data/Local | FavoriteLocalDataSourceTests（SwiftData in-memory）, FavoriteSchemaTests |
| Data/Remote | GitHubRemoteDataSourceTests（URLProtocol モック） |
| Data/Repository | SearchRepositoryImplTests, FavoriteRepositoryImplTests |

### UI Tests（XCUITest）

- 起動時のタブバー表示と初期画面の確認
- 3タブ間の遷移（検索 → お気に入り → 設定 → 検索）

### テスト手法のハイライト

- `MockURLProtocol` によるネットワークモック
- SwiftData `ModelConfiguration(isStoredInMemoryOnly: true)` でハーメティックな DB テスト
- Reducer は `TestStore` で検証（State の変化と受信する Action を網羅的に assert。依存は `withDependencies` でクロージャに差し替え）
- debounce は `TestClock` を進めて検証（実時間の待機なし）
- `// Arrange:` / `// Act:` / `// Assert:` の AAA コメント必須

## セットアップ

1. Xcode 27+ で `GitHubFinder.xcodeproj` を開く（初回は Swift Package の解決に数分かかります）
2. TCA などが提供するマクロの有効化を求めるダイアログが出たら **Trust & Enable** を選ぶ（コマンドラインでは `xcodebuild` に `-skipMacroValidation` を付ける。CI も同じ）
3. シミュレータを選択して Run

### Widget の動作確認

1. アプリ起動 → 検索 → お気に入りを数件登録
2. ホーム画面長押し → **+** → 「GitHubFinder」を検索 → 配置

### Widget と共有するコード

Widget Extension は `GitHubFinderKit` パッケージの `GitHubFinderData` / `GitHubFinderDomain` をリンクして App Group の SwiftData を読むため、個別ファイルの Target Membership 設定は不要。

### スキーマと文言

- SwiftData のモデル `FavoriteRecord` は `FavoriteSchemaV1`（`VersionedSchema`）の入れ子型で、将来のスキーマ変更は `FavoriteMigrationPlan` にステージを足して移行する。エンティティ名 `FavoriteRecord` は共有ストアのキーなので、テストで固定している。
- 文言は各パッケージ target と Widget がそれぞれ `Localizable.xcstrings` を持ち（`Text(..., bundle: #bundle)` で参照）、App 側のカタログは App ターゲットのコードで使う文字列だけを持つ。

GitHub API は認証なし（Rate Limit: 10 req/min）で動作します。

## 命名規則

| 種類 | 命名 |
|------|------|
| Entity | `〇〇Entity` |
| DTO | `〇〇DTO` |
| SwiftData Model | `〇〇Record` |
| Repository protocol | `〇〇RepositoryProtocol` |
| Repository 実装 | `〇〇RepositoryImpl` |
| DataSource | `〇〇RemoteDataSource` / `〇〇LocalDataSource` / `〇〇CacheDataSource` |
| Reducer | `〇〇Feature`（`State` / `Action` / `Destination` を入れ子で持つ） |
| 依存クライアント | `〇〇Client` |
| View | `〇〇View` |

## 関連リポジトリ

- 元になった iOS 版（SwiftUI + `@Observable`）: [KeitaArai8/github-finder-ios](https://github.com/KeitaArai8/github-finder-ios)。機能・ターゲット構成は共通で、プレゼンテーション層のみが異なります。
- 同一仕様の Android 版: [KeitaArai8/github-finder-android](https://github.com/KeitaArai8/github-finder-android)。設計思想・機能は共通で、技術スタックのみが異なります。

## オープンソース利用について

### ライセンス
[MIT License](./LICENSE) で公開しています。

### フォーク時の識別子置換

このリポジトリをフォークして利用する場合、以下の識別子を**自身のものに変更してください**:

| 項目 | サンプル値 | 変更先の例 |
|---|---|---|
| Bundle Identifier | `com.k-arai.GitHubFinder` | `com.yourdomain.GitHubFinder` |
| App Group | `group.com.example.GitHubFinder` | `group.com.yourdomain.GitHubFinder` |
| Widget Bundle ID | `com.k-arai.GitHubFinder.FavoriteWidget` | 同上 + Widget サフィックス |
| Team ID / Signing | 未設定（`DEVELOPMENT_TEAM` は空） | Xcode の **Signing & Capabilities** で設定 |

#### 変更箇所

1. **Xcode プロジェクト設定**
   - Targets → `GitHubFinder` / `FavoriteWidgetExtension` の **Bundle Identifier**
   - **Signing & Capabilities** タブの **App Groups**
2. **エンタイトルメント ファイル**
   - `GitHubFinder/GitHubFinder.entitlements`
   - `FavoriteWidgetExtension.entitlements`
3. **ソースコード**
   - [`AppGroupContainer.swift`](Packages/GitHubFinderKit/Sources/GitHubFinderData/AppGroup/AppGroupContainer.swift) の `identifier` 定数

### GitHub 商標について

本アプリは GitHub Inc. と無関係な学習用サンプルです。アプリ名・アイコンに公式 GitHub の商標を使用していません。

### GitHub API 利用について

[GitHub REST API Terms of Use](https://docs.github.com/en/site-policy/github-terms/github-terms-of-service) に準拠してください。このアプリが使う検索 API の認証なしのレートリミットは **10 req/min** です。

### セキュリティ

脆弱性を発見された場合は [SECURITY.md](./SECURITY.md) を参照してください。

### 免責事項

本アプリは**学習・教育目的のサンプル実装**です。本番環境での利用は自己責任でお願いします。Apple 公式サンプル相当の品質を目指していますが、特定用途への適合性を保証するものではありません。
