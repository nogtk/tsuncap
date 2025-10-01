# UIテストシナリオ計画

## 1. 目的と参照仕様
- 参照仕様: `spec/overall_specification.md` 5章・7章・9章・10章
- 実装計画: `docs/WORKPLAN.md` 3章「横断タスク」
- 目的: iOS UIのハッピーパスと重複処理分岐を自動化し、保存フローと主要エラーハンドリングの品質を担保する。

## 2. カバレッジ概要
| シナリオ | 仕様参照 | 自動化対象 | 確認ポイント |
| --- | --- | --- | --- |
| Happy Path 保存完走 | 5.1〜5.4, 7章, 10章 | 自動 | 画面遷移 (ホーム→スキャナ→確認→保存結果)、YAMLプレビュー表示、`Obsidianで開く` ボタン表示、保存結果トースト|
| 重複ISBN分岐 (更新選択) | 3章, 5.3, 7章, 9章, 10章 | 自動 | 既存ノート検出、更新選択肢提示、frontmatterマージ確認 |
| 重複ISBN分岐 (別名保存) | 3章, 5.3, 7章, 9章, 10章 | 自動 | `-2` 以降サフィックス生成、別名ファイル保存完了 |
| 保存失敗リカバリ | 9章 | 補助自動 (stub) | 書き込み不可擬似エラー時のフォルダ再選択導線・YAMLコピー導線 |
| オフライン保存 (タイトルのみ) | 9章, 10章 | 自動 (条件分岐テスト) | ネットワーク失敗時に最低限項目で保存完了 |
| OCRフォールバック導線 | 5.2, 7章 | 手動 | バーコード失敗からOCR導線が提示される |
| coverUrl 空保存 | 9章 | 自動 | API失敗時にcover空のまま保存できる |

※ 手動対象についても 6章でチェックリスト化。

## 3. 実装方針
- **テスト構造**: Page Object + Robot パターンで画面毎の操作APIを定義。
  - `HomeScreen`, `ScannerScreen`, `ConfirmScreen`, `SaveResultScreen`, `DuplicateDialog` を用意。
- **依存差し替え**: XCUIテスト起動時に `ProcessInfo.processInfo.arguments` で `-uiTestScenario` を受け取り、アプリをテスト用 DI コンテナに切り替える。
  - バックエンド依存: 書誌APIクライアントとファイル出力層をテストダブル（スタブ・フェイクファイルシステム）へ差し替え。
  - カメラ機能: テストモードではボタン押下で既定のISBNまたはOCR結果を注入。
- **テストデータ**: `UITestFixtures.swift` に以下を定義。
  - `happyPathBook`: ISBN `9784101010014` （夏目漱石『こころ』など実在データでslug動作確認）。
  - `duplicateExistingNote`: 既存 frontmatter をJSONで定義し、更新時マージ検証。
  - エラーケース: 書き込み失敗を強制する `FailingNoteWriter`。
- **ファイル検証**: テストモードではアプリ内 `FileStore` を `NSTemporaryDirectory()` 配下に固定し、保存完了後に UI 上でYAMLプレビューを表示。UITestはプレビューのテキスト検証と `FileStore` 状態 API を `XCUIApplication().staticTexts["savedFilePath"]` 等で取得。
- **ダイアログ操作**: Duplicate分岐は `XCUIApplication().sheets` でボタン押下 (`更新`, `別名保存`) を行う。
- **テスト命名規則**: `test_シナリオ_条件_期待` 形式。例: `test_happyPath_whenNewIsbn_createsMarkdownFile()`。

## 4. シナリオ詳細
### 4.1 ハッピーパス (新規保存)
1. `-uiTestScenario happyPath` で起動。
2. ホームで「キャプチャ」タップ。
3. スキャナ画面で `シミュレーション開始` ボタンを押下し、ISBN `9784101010014` を注入。
4. 確認画面でタイトル/著者/カテゴリが事前入力されていることを検証。
5. `保存` ボタン押下。
6. 保存結果画面で
   - `Obsidianで開く` ボタン表示
   - YAMLプレビューに `status: unread` と `addedDate`（今日の日付）が含まれる
   - `保存ファイル名` ラベルが `{isbn13}-{slug}.md`
7. YAMLプレビュー全文をテキスト比較し、`BookNoteTemplate.render` の期待値と一致することを`XCTAssertEqual`。

### 4.2 重複ISBN (更新)
1. `-uiTestScenario duplicateUpdate` で起動、テスト用 FileStore に既存ノートを配置。
2. 保存操作後、重複ダイアログで `更新` を選択。
3. 保存完了後のYAMLに既存ノートの `status` が維持され、他フィールドが更新されていることを比較。

### 4.3 重複ISBN (別名保存)
1. `-uiTestScenario duplicateNewCopy`。
2. 重複ダイアログで `別名保存` を選択。
3. 保存結果画面のファイル名が `-2.md` で終わることを確認し、FileStoreに異なるファイルが存在することを検証。

### 4.4 保存失敗リカバリ
1. `-uiTestScenario saveFailure`。
2. 保存時に書き込みエラーを発生させ、エラー画面で
   - 再試行ボタン
   - 「保存先を再選択」導線
   - YAMLコピー用`コピー`ボタン
   が表示されることを確認。
3. `コピー` ボタン押下後に、テキストフィールドに YAML が表示されることを確認。

### 4.5 オフライン保存 (タイトルのみ)
1. `-uiTestScenario offline`。
2. APIスタブが失敗レスポンスを返す。
3. 確認画面で coverUrl が空、カテゴリ未選択。
4. 保存後に YAML 内 `cover:` が空欄になっていることを確認。

## 5. 自動テストの補助コンポーネント
- `UITestAppLauncher`: launchArguments/Environmentを構成し、`XCTestCase` から使い回し。
- `XCUIElement+Wait`: 汎用待機ユーティリティ。
- `YamlAssertion`: YAML文字列比較のために余分な空白差分を無視するラッパー。

## 6. 手動確認が必要な領域
- OCRフォールバック画面の視認性・検出品質（実機カメラ依存）。
- 実ネットワークでのOpen Library / Google Books API応答バリエーション。
- iCloud Drive フォルダ選択フローの実デバイス挙動。
- 共有シートからObsidianを開いた際の挙動（Obsidianインストール有無別）。
- 実デバイスでの圏外状態保存（機内モードで確認）。これらは `docs/testing/manual_verification_checklist.md` にチェックリスト化。

## 7. 実行とCI連携
- `xcodebuild test -scheme tsuncap -destination "platform=iOS Simulator,name=iPhone 15" -only-testing:tsuncapUITests` で実行。
- CIでは happyPath, duplicateUpdate, duplicateNewCopy, offline の4本をSmoke、saveFailureはNightlyで実行。
- スクリーンショットは `XCTAttachment` で自動取得し、失敗時に保存。

## 8. 今後の課題
- Phase6/7/9の実装が完了し次第、テストダブルを実装コードに差し替え。
- VisionKit/AVFoundationの自動化検討（XCTestでのCameraシミュレーション課題）。
- 端末時計ずれによる `addedDate` の不一致対策としてテスト中は固定日時を注入。
