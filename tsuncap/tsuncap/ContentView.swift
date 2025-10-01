import SwiftUI

struct ContentView: View {
    private let metadata = BookMetadata(
        title: "Sample Book Title",
        authors: ["Sample Author"],
        categories: ["Sample"],
        isbn13: "9781234567897",
        coverUrl: "https://example.com/sample.jpg"
    )

    private var generatedSlug: String {
        Slugifier.makeSlug(from: metadata.title)
    }

    private var previewNote: String {
        BookNoteTemplate.render(metadata: metadata)
    }

    var body: some View {
        NavigationStack {
            List {
                Section("セットアップ") {
                    NavigationLink("iCloud フォルダアクセス検証") {
                        FolderAccessHarnessView()
                    }
                }

                Section("ツール") {
                    NavigationLink("ISBNスキャナ") {
                        ScannerScreen()
                    }
                }

                Section("保存ファイル名の例") {
                    Text("\(metadata.isbn13)-\(generatedSlug).md")
                        .textSelection(.enabled)
                }

                Section("差し込みYAMLプレビュー") {
                    Text(previewNote)
                        .font(.system(.body, design: .monospaced))
                        .textSelection(.enabled)
                }
            }
            .navigationTitle("Tsuncap 基盤")
        }
    }
}

#Preview {
    ContentView()
}
