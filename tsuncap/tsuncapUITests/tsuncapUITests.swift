import XCTest

enum UITestScenario: String {
    case happyPath
    case duplicateUpdate
    case duplicateNewCopy
    case saveFailure
    case offline
}

final class BookSaveFlowUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    func testHappyPath_whenNewIsbn_createsMarkdownFile() throws {
        try launch(with: .happyPath)
        throw XCTSkip("Phase6/7 実装およびUI遷移が未完成のため、自動検証は着手待ちです。")
    }

    func testDuplicateFlow_whenChoosingUpdate_mergesFrontmatter() throws {
        try launch(with: .duplicateUpdate)
        throw XCTSkip("Phase6/7 実装およびUI遷移が未完成のため、自動検証は着手待ちです。")
    }

    func testDuplicateFlow_whenChoosingNewCopy_generatesSuffixFile() throws {
        try launch(with: .duplicateNewCopy)
        throw XCTSkip("Phase6/7 実装およびUI遷移が未完成のため、自動検証は着手待ちです。")
    }

    func testOfflineMode_whenNetworkFails_savesWithMinimalFields() throws {
        try launch(with: .offline)
        throw XCTSkip("Phase6/7 実装およびUI遷移が未完成のため、自動検証は着手待ちです。")
    }

    func testSaveFailure_whenStorageUnavailable_promptsUserToRecover() throws {
        try launch(with: .saveFailure)
        throw XCTSkip("Phase6/9 実装およびUI遷移が未完成のため、自動検証は着手待ちです。")
    }

    private func launch(with scenario: UITestScenario) throws {
        app.launchArguments = ["-uiTestScenario", scenario.rawValue]
        app.launch()
    }
}
