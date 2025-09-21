import XCTest
@testable import tsuncap

final class ISBNScannerFactoryTests: XCTestCase {
    func testFactoryPrefersVisionKitWhenAvailable() {
        let availability = MockAvailabilityChecker(isAvailable: true)
        let expectedScanner = MockBarcodeCaptureSource()
        let factory = DefaultISBNScannerFactory(
            availabilityChecker: availability,
            visionKitBuilder: { expectedScanner },
            avFoundationBuilder: { MockBarcodeCaptureSource() }
        )

        let delegate = MockScannerDelegate()
        let produced = factory.makeScanner(delegate: delegate)

        XCTAssertTrue(produced === expectedScanner)
        XCTAssertTrue(expectedScanner.delegate === delegate)
    }

    func testFactoryFallsBackToAVFoundationWhenVisionKitUnavailable() {
        let availability = MockAvailabilityChecker(isAvailable: false)
        let expectedScanner = MockBarcodeCaptureSource()
        let factory = DefaultISBNScannerFactory(
            availabilityChecker: availability,
            visionKitBuilder: { MockBarcodeCaptureSource() },
            avFoundationBuilder: { expectedScanner }
        )

        let delegate = MockScannerDelegate()
        let produced = factory.makeScanner(delegate: delegate)

        XCTAssertTrue(produced === expectedScanner)
        XCTAssertTrue(expectedScanner.delegate === delegate)
    }
}

private final class MockBarcodeCaptureSource: BarcodeCaptureSource {
    weak var delegate: BarcodeCaptureSourceDelegate?

    func configure(in parent: UIViewController) throws {}
    func updateLayout(in parent: UIViewController) {}
    func startScanning() throws {}
    func stopScanning() {}
}

private final class MockScannerDelegate: NSObject, BarcodeCaptureSourceDelegate {
    func barcodeCaptureSource(_ source: BarcodeCaptureSource, didDetectRawValue rawValue: String) {}
    func barcodeCaptureSource(_ source: BarcodeCaptureSource, didFailWith error: Error) {}
}

private struct MockAvailabilityChecker: DataScannerAvailabilityChecking {
    var isAvailable: Bool

    func isVisionKitAvailable() -> Bool {
        isAvailable
    }
}
