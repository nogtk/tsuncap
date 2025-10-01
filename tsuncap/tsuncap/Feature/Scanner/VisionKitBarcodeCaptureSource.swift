#if canImport(VisionKit)
import UIKit
import VisionKit
#if canImport(Vision)
import Vision
#endif

@available(iOS 16.2, *)
@MainActor
final class VisionKitBarcodeCaptureSource: NSObject, BarcodeCaptureSource {
    weak var delegate: BarcodeCaptureSourceDelegate?

    private let dataScanner: DataScannerViewController

    override init() {
        dataScanner = DataScannerViewController(
            recognizedDataTypes: [.barcode(symbologies: [.ean13])],
            qualityLevel: .balanced,
            recognizesMultipleItems: false,
            isHighFrameRateTrackingEnabled: true,
            isHighlightingEnabled: true
        )
        super.init()
        dataScanner.delegate = self
    }

    func configure(in parent: UIViewController) throws {
        guard dataScanner.parent !== parent else { return }

        parent.addChild(dataScanner)
        parent.view.addSubview(dataScanner.view)

        dataScanner.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            dataScanner.view.leadingAnchor.constraint(equalTo: parent.view.leadingAnchor),
            dataScanner.view.trailingAnchor.constraint(equalTo: parent.view.trailingAnchor),
            dataScanner.view.topAnchor.constraint(equalTo: parent.view.topAnchor),
            dataScanner.view.bottomAnchor.constraint(equalTo: parent.view.bottomAnchor)
        ])

        dataScanner.didMove(toParent: parent)
    }

    func startScanning() throws {
        try dataScanner.startScanning()
    }

    func stopScanning() {
        dataScanner.stopScanning()
    }
}

@available(iOS 16.2, *)
extension VisionKitBarcodeCaptureSource: DataScannerViewControllerDelegate {
    func dataScanner(
        _ dataScanner: DataScannerViewController,
        didAdd addedItems: [RecognizedItem],
        allItems: [RecognizedItem]
    ) {
        for item in addedItems {
            guard case let .barcode(barcode) = item else { continue }
            guard let payload = barcode.payloadStringValue else { continue }
            delegate?.barcodeCaptureSource(self, didDetectRawValue: payload)
        }
    }

    func dataScanner(
        _ dataScanner: DataScannerViewController,
        becameUnavailableWithError error: Error
    ) {
        delegate?.barcodeCaptureSource(self, didFailWith: error)
    }
}
#endif
