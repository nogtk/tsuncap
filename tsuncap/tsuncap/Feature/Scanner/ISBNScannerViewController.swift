import UIKit

final class ISBNScannerViewController: UIViewController {
    private let viewModel: ISBNScannerViewModel
    private let factory: ISBNScannerFactory
    private var scanner: BarcodeCaptureSource?

    init(viewModel: ISBNScannerViewModel, factory: ISBNScannerFactory) {
        self.viewModel = viewModel
        self.factory = factory
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        configureScannerIfNeeded()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        synchronizeScanner()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        scanner?.stopScanning()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        scanner?.updateLayout(in: self)
    }

    func update(with state: ISBNScannerViewModel.State) {
        switch state {
        case .scanning:
            do {
                try scanner?.startScanning()
            } catch {
                viewModel.reportConfigurationFailure(error)
            }
        case .idle, .success, .invalid, .failure:
            scanner?.stopScanning()
        }
    }

    private func configureScannerIfNeeded() {
        guard scanner == nil else { return }
        let newScanner = factory.makeScanner(delegate: self)
        do {
            try newScanner.configure(in: self)
        } catch {
            viewModel.reportConfigurationFailure(error)
            return
        }
        scanner = newScanner
    }

    private func synchronizeScanner() {
        update(with: viewModel.state)
    }
}

extension ISBNScannerViewController: BarcodeCaptureSourceDelegate {
    func barcodeCaptureSource(
        _ source: BarcodeCaptureSource,
        didDetectRawValue rawValue: String
    ) {
        let shouldContinue = viewModel.handleDetected(rawValue: rawValue)
        if !shouldContinue {
            source.stopScanning()
        }
    }

    func barcodeCaptureSource(
        _ source: BarcodeCaptureSource,
        didFailWith error: Error
    ) {
        viewModel.reportConfigurationFailure(error)
    }
}
