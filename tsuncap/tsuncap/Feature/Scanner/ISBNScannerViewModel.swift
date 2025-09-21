import Combine
import Foundation

final class ISBNScannerViewModel: ObservableObject {
    enum State: Equatable {
        case idle
        case scanning
        case success(String)
        case invalid(code: String, reason: EAN13ValidationError)
        case failure(String)
    }

    @Published private(set) var state: State = .idle
    @Published private(set) var lastScannedISBN: String?

    var onValidISBN: ((String) -> Void)?

    var shouldRunScanner: Bool {
        if case .scanning = state {
            return true
        }
        return false
    }

    var statusMessage: String {
        switch state {
        case .idle,
             .scanning:
            return "バーコードを枠内に収めてください"
        case let .success(isbn):
            return "ISBN \(isbn) を読み取りました"
        case let .invalid(_, reason):
            return reason.errorDescription ?? "無効なバーコードです"
        case let .failure(message):
            return message
        }
    }

    func beginScanning() {
        lastScannedISBN = nil
        state = .scanning
    }

    func handleDetected(rawValue: String) -> Bool {
        do {
            let normalized = try EAN13Barcode.validate(rawValue)
            lastScannedISBN = normalized
            state = .success(normalized)
            onValidISBN?(normalized)
            return false
        } catch let validationError as EAN13ValidationError {
            lastScannedISBN = nil
            state = .invalid(code: rawValue, reason: validationError)
            return false
        } catch {
            state = .failure(error.localizedDescription)
            return false
        }
    }

    func reportConfigurationFailure(_ error: Error) {
        state = .failure(error.localizedDescription)
    }

    func retryScanning() {
        beginScanning()
    }

    func stopScanning() {
        state = .idle
    }
}
