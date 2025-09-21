import Combine
import Foundation

@MainActor
final class FolderAccessViewModel: ObservableObject {
    struct StatusMessage: Identifiable, Equatable {
        enum Kind {
            case info
            case success
            case error
        }

        let id = UUID()
        let kind: Kind
        let text: String

        static func info(_ text: String) -> StatusMessage {
            StatusMessage(kind: .info, text: text)
        }

        static func success(_ text: String) -> StatusMessage {
            StatusMessage(kind: .success, text: text)
        }

        static func error(_ text: String) -> StatusMessage {
            StatusMessage(kind: .error, text: text)
        }
    }

    struct HarnessAlert: Identifiable, Equatable {
        let id = UUID()
        let title: String
        let message: String
    }

    @Published var folderURL: URL?
    @Published var status: StatusMessage?
    @Published var alert: HarnessAlert?

    private let bookmarkController: FolderBookmarkController

    init(bookmarkController: FolderBookmarkController = FolderBookmarkController()) {
        self.bookmarkController = bookmarkController

        do {
            folderURL = try bookmarkController.resolveBookmark()
        } catch {
            alert = HarnessAlert(
                title: "ブックマーク復元エラー",
                message: error.localizedDescription
            )
        }
    }

    func handlePickedURLs(_ urls: [URL]) {
        guard let folderURL = urls.first else {
            status = StatusMessage.info("フォルダが選択されませんでした。")
            return
        }

        do {
            try bookmarkController.saveBookmark(for: folderURL)
            self.folderURL = try bookmarkController.resolveBookmark()
            status = StatusMessage.success("フォルダを登録しました。")
        } catch {
            alert = HarnessAlert(
                title: "フォルダ保存エラー",
                message: error.localizedDescription
            )
        }
    }

    func handlePickerCancelled() {
        status = StatusMessage.info("フォルダ選択をキャンセルしました。")
    }

    func refreshBookmarkState() {
        do {
            folderURL = try bookmarkController.resolveBookmark()
        } catch {
            alert = HarnessAlert(
                title: "ブックマーク復元エラー",
                message: error.localizedDescription
            )
        }
    }

    func createTestFile() {
        do {
            let fileURL = try bookmarkController.createTestFile()
            status = StatusMessage.success("書き込み成功: \(fileURL.lastPathComponent)")
        } catch let error as FolderBookmarkControllerError {
            switch error {
            case .bookmarkMissing:
                alert = HarnessAlert(
                    title: "フォルダ未設定",
                    message: "事前にフォルダを選択してください。"
                )
            default:
                alert = HarnessAlert(
                    title: "書き込みエラー",
                    message: error.localizedDescription
                )
            }
        } catch {
            alert = HarnessAlert(
                title: "想定外のエラー",
                message: error.localizedDescription
            )
        }
    }

    func clearBookmark() {
        bookmarkController.clearBookmark()
        folderURL = nil
        status = StatusMessage.info("保存済みブックマークを削除しました。")
    }
}
