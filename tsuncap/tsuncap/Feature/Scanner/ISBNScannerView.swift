import SwiftUI

struct ISBNScannerView: UIViewControllerRepresentable {
    @ObservedObject var viewModel: ISBNScannerViewModel
    var factory: ISBNScannerFactory

    func makeUIViewController(context: Context) -> ISBNScannerViewController {
        ISBNScannerViewController(viewModel: viewModel, factory: factory)
    }

    func updateUIViewController(_ uiViewController: ISBNScannerViewController, context: Context) {
        uiViewController.update(with: viewModel.state)
    }
}
