import SwiftUI

struct FolderAccessHarnessView: View {
    @StateObject private var viewModel = FolderAccessViewModel()
    @State private var showingPicker = false

    var body: some View {
        Form {
            Section("選択フォルダ") {
                if let url = viewModel.folderURL {
                    Label(url.lastPathComponent, systemImage: "folder")
                    Text(url.path)
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .textSelection(.enabled)
                } else {
                    Text("未設定")
                        .foregroundColor(.secondary)
                }

                Button("フォルダを選択") {
                    showingPicker = true
                }

                if viewModel.folderURL != nil {
                    Button("ブックマークを削除", role: .destructive) {
                        viewModel.clearBookmark()
                    }
                }
            }

            Section("書き込み検証") {
                Button("テストファイルを書き込む") {
                    viewModel.createTestFile()
                }

                if let status = viewModel.status {
                    Text(status.text)
                        .font(.footnote)
                        .foregroundColor(color(for: status.kind))
                        .textSelection(.enabled)
                }
            }
        }
        .navigationTitle("iCloud フォルダ設定")
        .sheet(isPresented: $showingPicker) {
            FolderDocumentPicker(
                onPicked: { urls in
                    showingPicker = false
                    viewModel.handlePickedURLs(urls)
                },
                onCancel: {
                    showingPicker = false
                    viewModel.handlePickerCancelled()
                }
            )
            .ignoresSafeArea()
        }
        .alert(item: $viewModel.alert) { alert in
            Alert(
                title: Text(alert.title),
                message: Text(alert.message),
                dismissButton: .default(Text("OK"))
            )
        }
    }

    private func color(for kind: FolderAccessViewModel.StatusMessage.Kind) -> Color {
        switch kind {
        case .info:
            return .secondary
        case .success:
            return .green
        case .error:
            return .red
        }
    }
}

#Preview {
    NavigationStack {
        FolderAccessHarnessView()
    }
}
