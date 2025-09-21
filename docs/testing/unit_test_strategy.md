# 単体テスト戦略（Utilities / Models / Mapping）

## 1. テストケース一覧と優先順位
| 対象 | テストケース | 観点 | 優先度 |
| --- | --- | --- | --- |
| DateFormatting | 異なるタイムゾーン・日付跨ぎ・うるう日 | addedDate の境界値 | P0 |
| Slugifier | 空文字・制御文字・ダイアクリティカル・大文字保持 | ファイル名スラッグの安全性 | P0 |
| TemplateRenderer / BookNoteTemplate | YAML 差し込み、配列・改行エスケープ、未定義トークン | フロントマターの整合性 | P0 |
| BookMetadata 初期化子 | デフォルト配列、テンプレ生成との整合 | モデル層の初期状態 | P1 |
| OpenLibrary マッピング | タイトル/サブタイトル結合、著者解決、subjects→カテゴリ（重複除去）、ISBN 必須、カバーURL生成 | API マッピングのモックテスト | P0 |
| GoogleBooks マッピング | industryIdentifiers から ISBN13、画像リンク優先順位/HTTPS 化、カテゴリ制限 | API マッピングのモックテスト | P0 |
| HTTPClient | タイムアウト再試行、5xx 再試行、4xx 非再試行、ログ呼び出し | フェーズ0 ネットワーク層の安定性 | P0 |
| 今後追加: Mapper 例外系 | 欠損フィールド・不正フォーマット | エラーロギングの検証 | P1 |
| 今後追加: Frontmatter マージ | 既存ノート更新時の差分適用 | フェーズ6 依存 | P1 |

## 2. テストスイート構成
- `tsuncap/tsuncapTests/UtilitiesTests.swift`
  - `DateFormattingTests`, `SlugifierTests`, `BookMetadataTests`, `YAMLTemplateRendererTests`, `TemplateRendererEscapingTests`
  - `OpenLibraryMappingTests`, `GoogleBooksMappingTests`（JSON モックで API → モデルの主要パスを検証）
- `tsuncap/tsuncapTests/HTTPClientTests.swift`
  - URLProtocol ベースのモックでリトライとログ呼び出しを検証

## 3. 実行方法（CI / ローカル）
```
xcodebuild test -project tsuncap/tsuncap.xcodeproj -scheme tsuncap -destination 'platform=iOS Simulator,name=iPhone 15,OS=latest'
```
- CI では `OS=latest` を指定し、ランナーにインストール済みの iOS シミュレータを自動選択。
- 成果物として `Test.xcresult` を保存するとログ解析が容易です。

## 4. 今後のガイドライン
1. **テスト追加前に spec/overall_specification.md を再確認**: フィールド優先度やテンプレ差し込みルールの変更有無を確認する。
2. **フィクスチャは JSON 文字列 or `Resources/Fixtures`**: 実 API との差異が分かるよう最小限の整形コメントを付与し、`decodeJSON` ヘルパーを再利用する。
3. **カテゴリ / 著者は大文字小文字を無視して重複排除**: 実装とテストの両方でユーティリティ関数を利用して一貫性を担保する。
4. **日付系は TimeZone を明示**: 期待値が実行環境に依存しないよう `TimeZone(secondsFromGMT:)` を固定する。
5. **失敗ケースは例外型まで検証**: `BookMetadataMappingError` 等の enum 比較でリグレッションを防止する。
6. **将来のテンプレ差分**: フロントマターの追加フィールドはテンプレートとユーティリティ両方にテストを追加し、スナップショット更新の PR を分離する。
