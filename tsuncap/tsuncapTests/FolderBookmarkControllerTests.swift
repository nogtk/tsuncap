import XCTest
@testable import tsuncap

final class FolderBookmarkControllerTests: XCTestCase {
    private var temporaryDirectory: URL!
    private var suiteName: String!
    private var defaults: UserDefaults!
    private var controller: FolderBookmarkController!

    override func setUpWithError() throws {
        try super.setUpWithError()

        temporaryDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(
            "FolderBookmarkControllerTests-\(UUID().uuidString)",
            isDirectory: true
        )
        try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)

        suiteName = "FolderBookmarkControllerTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            XCTFail("UserDefaults suite を初期化できませんでした")
            return
        }
        defaults.removePersistentDomain(forName: suiteName)
        self.defaults = defaults

        controller = FolderBookmarkController(dataStore: UserDefaultsBookmarkStore(userDefaults: defaults))
    }

    override func tearDownWithError() throws {
        if let defaults, let suiteName {
            defaults.removePersistentDomain(forName: suiteName)
        }
        try? FileManager.default.removeItem(at: temporaryDirectory)

        controller = nil
        defaults = nil
        temporaryDirectory = nil
        suiteName = nil

        try super.tearDownWithError()
    }

    func testResolveBookmarkWithoutSavingReturnsNil() throws {
        let resolved = try controller.resolveBookmark()
        XCTAssertNil(resolved)
    }

    func testSaveAndResolveBookmark() throws {
        try controller.saveBookmark(for: temporaryDirectory)
        let resolved = try controller.resolveBookmark()

        XCTAssertEqual(
            resolved?.standardizedFileURL,
            temporaryDirectory.standardizedFileURL
        )
    }

    func testCreateTestFileWritesCustomContents() throws {
        try controller.saveBookmark(for: temporaryDirectory)

        let fileURL = try controller.createTestFile(
            prefix: "unit-test",
            contents: "Hello, bookmark!",
            fileExtension: "md"
        )

        let loaded = try String(contentsOf: fileURL, encoding: .utf8)
        XCTAssertEqual(loaded, "Hello, bookmark!")
        XCTAssertEqual(
            fileURL.deletingLastPathComponent().standardizedFileURL,
            temporaryDirectory.standardizedFileURL
        )
    }

    func testCreateTestFileWithoutBookmarkThrows() {
        XCTAssertThrowsError(try controller.createTestFile()) { error in
            guard let bookmarkError = error as? FolderBookmarkControllerError else {
                XCTFail("想定外のエラー: \(error)")
                return
            }

            if case .bookmarkMissing = bookmarkError {
                // expected
            } else {
                XCTFail("bookmarkMissing を期待しましたが、\(bookmarkError) が返されました")
            }
        }
    }

    func testClearBookmarkRemovesStoredData() throws {
        try controller.saveBookmark(for: temporaryDirectory)
        controller.clearBookmark()

        let resolved = try controller.resolveBookmark()
        XCTAssertNil(resolved)
    }
}
