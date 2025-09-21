import XCTest
@testable import tsuncap

final class ISBNScannerViewModelTests: XCTestCase {
    func testBeginScanningSetsStateToScanning() {
        let viewModel = ISBNScannerViewModel()
        viewModel.beginScanning()
        if case .scanning = viewModel.state {
            // OK
        } else {
            XCTFail("State should be scanning")
        }
        let shouldRun = viewModel.shouldRunScanner
        XCTAssertTrue(shouldRun)
    }

    func testHandleValidIsbnUpdatesStateToSuccess() {
        let viewModel = ISBNScannerViewModel()
        viewModel.beginScanning()
        let shouldContinue = viewModel.handleDetected(rawValue: "9784873117584")
        XCTAssertFalse(shouldContinue)
        if case let .success(isbn) = viewModel.state {
            XCTAssertEqual(isbn, "9784873117584")
        } else {
            XCTFail("Expected success state")
        }
        let lastISBN = viewModel.lastScannedISBN
        XCTAssertEqual(lastISBN, "9784873117584")
    }

    func testHandleInvalidIsbnUpdatesStateToInvalid() {
        let viewModel = ISBNScannerViewModel()
        viewModel.beginScanning()
        let shouldContinue = viewModel.handleDetected(rawValue: "9784873117585")
        XCTAssertFalse(shouldContinue)
        if case let .invalid(_, reason) = viewModel.state {
            XCTAssertEqual(reason, .invalidCheckDigit(expected: 4, actual: 5))
        } else {
            XCTFail("Expected invalid state")
        }
    }

    func testReportConfigurationFailureSetsFailureState() {
        let viewModel = ISBNScannerViewModel()
        viewModel.reportConfigurationFailure(AVFoundationBarcodeCaptureError.cameraUnavailable)
        guard case let .failure(message) = viewModel.state else {
            XCTFail("Expected failure state")
            return
        }
        let containsCamera = message.contains("camera")
        XCTAssertTrue(containsCamera)
    }

    func testRetryScanningReturnsToScanning() {
        let viewModel = ISBNScannerViewModel()
        viewModel.beginScanning()
        _ = viewModel.handleDetected(rawValue: "9784873117584")
        viewModel.retryScanning()
        if case .scanning = viewModel.state {
            // OK
        } else {
            XCTFail("State should return to scanning")
        }
    }
}
