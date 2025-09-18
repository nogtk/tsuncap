# Tsuncap

## プロジェクト概要
- 本屋で取得したISBNや表紙画像からメタデータを検索し、Obsidian Vault（iCloud Drive 上）の`bookLog/memo`へ指定テンプレートのMarkdownを生成・保存するiOSアプリです（spec/overall_specification.md 0章）。
- 対応端末はiPhone（iOS 16以降）、配布形態はApp Store外の自己ビルドを想定しています。
- 画像ファイルは端末へ保存せず、取得したカバー画像のURLのみをfrontmatterに保持します。

## 動作環境と前提
- macOS Sonoma 以降 / Apple Silicon または Intel Mac。Xcode 15.4 以上を推奨します。
- Apple Developer Program 加入済みの個人またはチームアカウント。
- 実機: iOS 16 以上を搭載した iPhone。シミュレータでもビルドは可能ですが、カメラ・DocumentPicker の検証は実機必須です。
- Obsidian Vault を iCloud Drive 上に作成し、`bookLog/memo` フォルダを用意してください。

## セットアップ手順
1. リポジトリを取得し、`tsuncap.xcodeproj` を Xcode で開きます。
2. `Signing & Capabilities` でチームを設定し、バンドルIDを一意な値へ変更してください（例: `com.example.tsuncap`）。
3. `File Access` / `iCloud Documents` を利用するため、`iCloud` と `App Groups` の有効化が必要な場合はチームポリシーに従って設定します。
4. `Info.plist` に `NSCameraUsageDescription` が定義されていることを確認し、必要に応じて文言を調整します（spec 4章 カメラ利用）。
5. 初回は `Product > Build` でビルドし、依存Swift Packageを解決した後、`Product > Run` でターゲット端末へデプロイします。

## 必要権限とOS設定
- カメラ: ISBNバーコード読み取りに必須（spec 4章 スキャン）。アプリ初回起動時に許可ダイアログが表示されます。
- 写真ライブラリ: 仕様上は保持しないため不要です。
- iCloud Drive: UIDocumentPicker 経由で Obsidian Vault にアクセスするため、設定アプリの「Apple ID > iCloud > iCloud Drive」を有効化してください。
- ネットワーク: Open Library / Google Books へのアクセスに必要です。企業ネットワークの場合はプロキシ例外を設定してください。

## 依存タスクと推奨実行順
- docs/WORKPLAN.md 3章の横断タスクに基づき、フェーズ単位で以下の順に着手すると設定・ビルドがスムーズです。
  - Phase0: プロジェクト基盤・ユーティリティ整備。
  - Phase1: UIDocumentPicker とセキュリティスコープ付きブックマークの導入（本READMEの手順と密接に連携）。
  - Phase2〜6: スキャン・書誌取得・YAML生成・ファイル出力の骨格。
  - Phase7: UI 4画面の実装（spec 7章）と動線確認。
  - Phase8〜9: 設定画面とエラーハンドリングの強化。
  - Phase10: 共有シートなど連携機能の仕上げ。
- Phase1 → Phase7 → Phase10 の順で依存が強いため、フォルダ選択・UI仕上げ・共有シートをこの順番で検証してください。

## UIDocumentPicker によるフォルダ選択手順
1. 初回起動または設定画面から「保存先フォルダを選択」をタップします。
2. `UIDocumentPickerViewController` が開いたら「ブラウズ」→「iCloud Drive」→ Obsidian の Vault を選択し、`bookLog` フォルダ内の `memo` を開きます。
3. 右上の「開く」または「追加」をタップしてフォルダを確定します。アプリはセキュリティスコープ付きブックマークを保存し、次回以降は許可なしで書き込みます（spec 4章 ファイル書き込み、Phase1 完了条件）。
4. フォルダを変更したい場合は設定画面から再選択し、既存ブックマークを破棄してください。

## 共有シート（Obsidian 連携）の利用手順
1. 書き込みに成功すると完了画面に「Obsidianで開く」「ファイル表示」などのアクションが表示されます（spec 7章 保存結果）。
2. 「Obsidianで開く」を選択すると共有シートが立ち上がるので、Obsidian を選択してください。`obsidian://open` が利用できない環境では、共有先一覧から「ファイル」アプリで開く→Obsidianで読み込む運用も可能です（spec 4章 Obsidian 連携、Phase10）。
3. 共有シートをカスタマイズしたい場合は、iOS の「共有」設定で Obsidian を上位に配置しておくと作業が効率化します。

## 実機検証とテスト
- docs/WORKPLAN.md 3章の指針に従い、ユーティリティはユニットテスト、保存フローはUIテスト、カメラ/書込は実機で検証します。
- 実機検証: デバイスをMacへ接続し、`Product > Destination` で対象iPhoneを選択してから `Product > Run` を実行します。バーコード読み取りとフォルダ書き込みの動作を必ず確認してください。
- シミュレータテスト: バーコード/DocumentPicker動作は限定的ですが、`xcodebuild test -scheme tsuncap -destination 'platform=iOS Simulator,name=iPhone 15,OS=17.5'` で主要ユニット/UIテストを回せます。
- 実装追加時は、テンプレ生成のスナップショットテストや重複処理のUIテスト（Phase6〜7依存）を追加し、ハッピーパスと重複分岐の両方を回帰確認してください。

## VS Code タスクによるシミュレータビルド
- `.vscode/tasks.json` にはシミュレータの起動からアプリのビルド・インストール・起動までを自動化するタスクが定義されています。
  1. `open simulator ui`: `open -a Simulator` でシミュレータアプリを起動します。
  2. `boot & wait simulator`: `xcrun simctl boot "iPhone 17"` → `simctl bootstatus` でブート完了を待機します。
  3. `build app (sim)`: `xcodebuild -scheme tsuncap -project tsuncap/tsuncap.xcodeproj -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath .vscode_build` を実行し、Simulator用ビルド成果物を `.vscode_build` に出力します。
  4. `install app (sim)`: `xcrun simctl install booted .vscode_build/Build/Products/Debug-iphonesimulator/tsuncap.app` でビルド済みアプリをインストールします。
  5. `launch app (sim)`: `xcrun simctl launch booted nogtk.tsuncap` で起動します。
- 2025-09-19 時点で上記コマンドを順に実行し、`iPhone 17` シミュレータで `tsuncap.app` が起動することを確認済みです。
- VS Code から利用する場合は `⇧⌘B` で `launch app (sim)` タスクを選択すると依存タスクが順番に走ります。タスクが失敗した際は `.vscode_build` を削除してから再試行してください。

## トラブルシューティング
- カバー画像URLが取得できない場合は Open Library → Google Books の順で再試行し、それでも不可なら空のまま保存できます（spec 4章 オンライン検索）。
- フォルダ書き込みに失敗した場合は設定からフォルダ再選択を行い、必要に応じて生成されたYAMLをクリップボードにコピーして手動保存してください。
