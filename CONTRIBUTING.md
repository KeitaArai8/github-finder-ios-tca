# Contributing to GitHubFinder (iOS / TCA 版)

本プロジェクトへのコントリビューションに興味を持っていただきありがとうございます。このドキュメントは、Issue 報告・PR 送付時のガイドラインをまとめたものです。

## 前提

本リポジトリは **学習・教育目的のサンプルアプリ** です。2026 年時点の iOS デファクトスタンダード（SwiftUI + The Composable Architecture + SwiftData + Swift Testing + WidgetKit）に準拠した設計のリファレンス実装を目指しています。

本質的なアーキテクチャを逸脱する大規模な変更は、Discussion で事前に方向性を合意してから PR をお願いします。

## セットアップ

1. Xcode 27+ をインストール
2. リポジトリをフォーク & クローン
3. `GitHubFinder.xcodeproj`（リポジトリ直下） を Xcode で開く
4. シミュレータを選んで Run

### 識別子の置換

フォーク直後はビルドが通らない場合があります。[README](./README.md#フォーク時の識別子置換) の手順で自身の Bundle ID / App Group に置換してください。

## ブランチ命名

| 用途 | 命名 | 例 |
|---|---|---|
| 新機能 | `feature/<short-name>` | `feature/dark-mode-toggle` |
| バグ修正 | `fix/<issue-id>-<short-name>` | `fix/123-favorite-state` |
| ドキュメント | `docs/<short-name>` | `docs/widget-setup` |
| リファクタ | `refactor/<short-name>` | `refactor/search-model-split` |

## コミットメッセージ

[Conventional Commits](https://www.conventionalcommits.org/) に従ってください。

```
<type>: <subject>

[optional body]

[optional footer]
```

### type の例

- `feat`: 新機能
- `fix`: バグ修正
- `docs`: ドキュメントのみ
- `style`: コード整形（挙動変更なし）
- `refactor`: リファクタリング
- `test`: テスト追加・修正
- `chore`: その他（依存更新、CI 設定等）

### 例

```
feat: お気に入りの一括選択削除機能を追加

FavoriteFeature に編集モードの State を追加し、選択中のアイテムを
まとめて削除できるようにした。削除確認ダイアログで誤操作を防止。

Closes #42
```

## コードスタイル

- **Swift API Design Guidelines** に準拠
- 頭字語（ID / URL / API 等）は **全大文字 or 全小文字**で統一
- 1関数は **25 行以内**を目安に
- 引数 3 つ以上は**1 引数ごとに改行**
- `guard let` による **早期リターン** を優先
- **View 内でビジネスロジックを書かない**（Passive View 原則）

本プロジェクト固有のルールは README とコードベースから読み取ってください。

## テスト

- Reducer を変更する場合は **対応する `TestStore` のテストを必ず追加・更新**
- Data 層（Repository / DataSource）変更時も同様
- テストは **Swift Testing** (`@Test`, `#expect`, `#require`) で記述
- AAA パターン（`// Arrange:` / `// Act:` / `// Assert:`）のコメントを各テストに明記

## Preview の追加

新規 View を追加する場合、可能な限り `#Preview` を追加してください。Preview 用の Store は既存の `makePreviewStore { ... }`（State を直接組み立て、`EmptyReducer` で表示する）パターンを参考にしてください。

## PR の送付

1. フォークしたリポジトリに push
2. 元リポジトリへ Pull Request を作成
3. PR テンプレートに従って内容を記述
4. CI (Build & Test) が緑になることを確認
5. レビューコメントに対応

### マージ基準

- CI 緑
- 最低 1 名のレビュー承認
- コンフリクトなし
- PR テンプレートのチェックリストを全てクリア

## セキュリティ脆弱性

公開 Issue は作成せず、[SECURITY.md](./SECURITY.md) の手順で報告してください。

## 行動規範

コントリビューター全員が [Code of Conduct](./CODE_OF_CONDUCT.md) を遵守してください。

## ライセンス

コントリビュートされたコードは [MIT License](./LICENSE) で公開されることに同意したものとみなします。
