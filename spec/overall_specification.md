# Tsuncap 仕様書（iOS・自分用 / 画像はURL参照のみ）

## 0. 概要
- **目的**: 本屋で撮った写真やバーコードから本を特定し、Obsidian の Vault（iCloud 上）に所定テンプレの Markdown を自動生成・保存する。  
- **対象端末/OS**: iPhone（iOS 16+）  
- **配布**: Xcode で自己ビルド（App Store なし）  
- **保存先**: iCloud Drive の Obsidian Vault → `bookLog/memo`  
- **画像の取り扱い**: **ローカル保存しない**。frontmatter `cover` は **HTTP の画像URL**を格納。

---

## 1. ユーザーストーリー（ハッピーパス）
1. アプリ起動 → 「キャプチャ」  
2. **ISBN-13** をバーコードで検出（失敗時は表紙撮影→OCRでタイトル/著者抽出）  
3. **オンライン検索**（Open Library / Google Books）でメタデータ・**カバー画像URL**取得  
4. **確認画面**で編集（タイトル/著者/カテゴリ、ISBN、coverURL）  
5. 「保存」→ `bookLog/memo` に Markdown を生成（テンプレ差し込み）

---

## 2. テンプレート & フィールド仕様

### 2.1 ユーザー指定テンプレート（厳守）
```yaml
---
title: "{{title}}"
authors: [{{author}}]
category: [{{category}}]
isbn: {{isbn13}}
cover: {{coverUrl}}
status: unread
addedDate: {{DATE:YYYY-MM-DD}}
finishedDate:
---
```

### 2.2 差し込みルール
- **title**: API結果（優先）→OCR→手入力  
- **author**: API結果（複数可）。テンプレでは `authors: ["A","B"]` 形式に整形  
- **category**: APIのカテゴリ/subjects から 1–3 個サジェスト → ユーザー選択（空可）  
- **isbn13**: バーコード or API結果（EAN-13 正規化とチェックデジット検証）  
- **coverUrl**: API から得た **HTTP(S) URL**（高解像度優先）。ローカル保存は行わない  
- **status**: 既定 `unread`（UIで変更可）  
- **addedDate**: 端末ローカル日付（`YYYY-MM-DD`）  
- **finishedDate**: 空（ステータス `finished` 選択時に自動入力可能）

---

## 3. ファイル出力仕様（Obsidian）
- **保存フォルダ**: `bookLog/memo/`  
- **ファイル名規則**: `{isbn13}-{slug(title)}.md`  
  - slug: 半角英数とハイフン基調。日本語はそのままでも可（既定はそのまま＋パス安全化）  
- **重複処理**: 同一 ISBN ノートが存在 → 「更新 or 別名保存（-2, -3…）」選択  
- **文字コード**: UTF-8 / LF  
- **本文**: 今回は空でOK（将来拡張余白1行を末尾に入れる）

---

## 4. アプリ構成（iOS）
- **UI**: SwiftUI  
- **スキャン**:  
  - 可能なら **VisionKit DataScannerViewController**（バーコード+テキスト同時）  
  - フォールバック: **AVFoundation**（EAN-13/EAN-8）＋ **Vision OCR**（日本語/英語）  
- **オンライン検索**  
  - 優先1: **Open Library**（キー不要、Covers API で画像URL組み立て）  
  - 優先2: **Google Books**（無料枠、画像URLは `imageLinks`）  
  - 競合時のフィールド優先: *ISBN > タイトル > 著者*。カテゴリは1–3件に間引き  
- **HTTP**: `URLSession`（タイムアウト/再試行）  
- **ファイル書き込み**: 初回に `bookLog/memo` フォルダを **UIDocumentPicker** で選択 → セキュリティスコープ付きブックマークを保存 → 以降は `FileManager` で直接書き込み  
- **Obsidian 連携**: 保存完了後に共有シートで「Obsidianで開く」を提示（`obsidian://open` はパス相性のため任意）

---

## 5. 画面仕様

### 5.1 ホーム
- 「キャプチャ」ボタン  
- 最近保存3件（タイトル/日付/ステータス）  
- 設定：保存先フォルダ再選択、API優先度、既定ステータス/カテゴリ

### 5.2 スキャナ
- ライブプレビュー、ISBNヒット時はヘッダに表示  
- バーコード未検出時：「表紙を撮影→OCRで検索」導線

### 5.3 確認/編集
- 入力: タイトル、著者（複数対応UI）、カテゴリ（複数）、ISBN（表示のみ・コピー可）、coverUrl（編集可）  
- プレビュー: テンプレ差し込みYAMLの確認（読み取り専用）

### 5.4 保存結果
- 成功トースト＋「Obsidianで開く」「ファイル表示」  
- 失敗時に詳細エラー表示＋「内容をコピー」ボタン（手貼り用）

---

## 6. 外部API 仕様（実装目安）

### 6.1 Open Library
- 書誌: `https://openlibrary.org/isbn/{isbn}.json`  
- 著者名取得: `authors[].key` を `https://openlibrary.org{key}.json` で解決  
- カバー: `https://covers.openlibrary.org/b/isbn/{isbn}-L.jpg`  
- マッピング例:  
  - `title` → title  
  - `authors[].name` → authors[]  
  - `subjects[]` → category 候補  
  - `isbn_13[]` → isbn13  
  - coverUrl → Covers API の URL

### 6.2 Google Books
- 検索: `https://www.googleapis.com/books/v1/volumes?q=isbn:{isbn}`  
- マッピング例:  
  - `volumeInfo.title` → title  
  - `volumeInfo.authors[]` → authors[]  
  - `volumeInfo.categories[]` → category 候補  
  - `industryIdentifiers[ISBN_13]` → isbn13  
  - `imageLinks.thumbnail / large` → coverUrl

---

## 7. 保存ロジック（擬似コード）
```pseudo
onSave():
  data = {title, authors[], categories[], isbn13, coverUrl}
  yaml = renderTemplate(data, date=Today("YYYY-MM-DD"))
  filename = `${isbn13}-${slug(title)}.md`
  url = resolveScopedBookmarkTo(bookLog/memo)
  if exists(url/filename):
    choice = askUser("更新 or 別名保存")
    if choice == "更新": mergeFrontmatter(url/filename, data)
    else: filename = disambiguate(filename)  // -2, -3...
  writeTextFile(url/filename, yaml + "\n")
  showSuccessActions()
```

---

## 8. 設定項目
- 保存先フォルダ（`bookLog/memo`）選択・再選択  
- API優先順位（既定: Open Library → Google Books）  
- 既定ステータス（`unread`）  
- 既定カテゴリ（任意・空可）

---

## 9. エラーハンドリング
- **バーコード検出不可**: 表紙撮影→OCR→API検索→それでも不可なら最小入力（タイトルのみ）で保存可能  
- **API失敗/圏外**: coverUrl 空のまま保存可  
- **書き込み不可**: フォルダ再選択ダイアログ＋生成済みYAMLをクリップボードへ  
- **重複ISBN**: 既存ノートを検出し、更新/別名の選択肢を提示

---

## 10. 受け入れ基準
- 保存時、`bookLog/memo` にテンプレ通りの **Markdown** が作成されること  
- `cover` は **HTTP(S) の画像URL** を保持し、ローカル画像保存は**行わない**こと  
- 同一ISBNが既存の場合、**更新/別名**の選択を出すこと  
- オフラインでも、タイトルのみで保存できること  
- 保存後に「Obsidianで開く」導線があること
