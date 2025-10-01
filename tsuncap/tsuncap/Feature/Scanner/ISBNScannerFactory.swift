import UIKit

#if canImport(VisionKit)
import VisionKit
#endif

protocol BarcodeCaptureSourceDelegate: AnyObject {
    func barcodeCaptureSource(
        _ source: BarcodeCaptureSource,
        didDetectRawValue rawValue: String
    )

    func barcodeCaptureSource(
        _ source: BarcodeCaptureSource,
        didFailWith error: Error
    )
}

protocol BarcodeCaptureSource: AnyObject {
    var delegate: BarcodeCaptureSourceDelegate? { get set }

    func configure(in parent: UIViewController) throws
    func updateLayout(in parent: UIViewController)
    func startScanning() throws
    func stopScanning()
}

extension BarcodeCaptureSource {
    func updateLayout(in parent: UIViewController) {}
}

protocol DataScannerAvailabilityChecking {
    func isVisionKitAvailable() -> Bool
}

protocol ISBNScannerFactory {
    func makeScanner(delegate: BarcodeCaptureSourceDelegate) -> BarcodeCaptureSource
}

typealias BarcodeCaptureSourceBuilder = () -> BarcodeCaptureSource

struct DefaultISBNScannerFactory: ISBNScannerFactory {
    private let availabilityChecker: DataScannerAvailabilityChecking
    private let visionKitBuilder: BarcodeCaptureSourceBuilder?
    private let avFoundationBuilder: BarcodeCaptureSourceBuilder

    init(
        availabilityChecker: DataScannerAvailabilityChecking = RealDataScannerAvailabilityChecker(),
        visionKitBuilder: BarcodeCaptureSourceBuilder? = nil,
        avFoundationBuilder: @escaping BarcodeCaptureSourceBuilder = {
            AVFoundationBarcodeCaptureSource()
        }
    ) {
        self.availabilityChecker = availabilityChecker
        #if canImport(VisionKit)
        if let builder = visionKitBuilder {
            self.visionKitBuilder = builder
        } else if #available(iOS 16.2, *) {
            self.visionKitBuilder = {
                VisionKitBarcodeCaptureSource()
            }
        } else {
            self.visionKitBuilder = nil
        }
        #else
        self.visionKitBuilder = nil
        #endif
        self.avFoundationBuilder = avFoundationBuilder
    }

    func makeScanner(delegate: BarcodeCaptureSourceDelegate) -> BarcodeCaptureSource {
        if let dataScanner = prepareVisionKitScanner(delegate: delegate) {
            return dataScanner
        }
        return prepareAVFoundationScanner(delegate: delegate)
    }

    private func prepareVisionKitScanner(delegate: BarcodeCaptureSourceDelegate) -> BarcodeCaptureSource? {
        guard availabilityChecker.isVisionKitAvailable() else {
            return nil
        }

        guard let builder = visionKitBuilder else {
            return nil
        }

        let scanner = builder()
        scanner.delegate = delegate
        return scanner
    }

    private func prepareAVFoundationScanner(delegate: BarcodeCaptureSourceDelegate) -> BarcodeCaptureSource {
        let scanner = avFoundationBuilder()
        scanner.delegate = delegate
        return scanner
    }
}

struct RealDataScannerAvailabilityChecker: DataScannerAvailabilityChecking {
    func isVisionKitAvailable() -> Bool {
        #if canImport(VisionKit)
        if #available(iOS 16.2, *) {
            return DataScannerViewController.isSupported && DataScannerViewController.isAvailable
        } else {
            return false
        }
        #else
        return false
        #endif
    }
}
