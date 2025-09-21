import SwiftUI

struct ScannerScreen: View {
    @StateObject private var viewModel = ISBNScannerViewModel()
    private let factory: ISBNScannerFactory

    init(factory: ISBNScannerFactory = DefaultISBNScannerFactory()) {
        self.factory = factory
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            ISBNScannerView(viewModel: viewModel, factory: factory)
                .ignoresSafeArea()

            bottomOverlay
        }
        .background(Color.black.ignoresSafeArea())
        .toolbar(.hidden, for: .tabBar)
        .onAppear { viewModel.beginScanning() }
        .onDisappear { viewModel.stopScanning() }
        .navigationTitle("ISBNスキャナ")
    }

    @ViewBuilder
    private var bottomOverlay: some View {
        VStack(spacing: 12) {
            Text(viewModel.statusMessage)
                .font(.headline)
                .multilineTextAlignment(.center)

            switch viewModel.state {
            case .success(let isbn):
                Text("取得したISBN: \(isbn)")
                    .font(.body)
                Button("続けてスキャン") {
                    viewModel.retryScanning()
                }
                .buttonStyle(.borderedProminent)

            case .invalid(let code, let reason):
                Text("検出値: \(code)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                Text(reason.errorDescription ?? "無効なバーコードです")
                    .font(.body)
                Button("再試行") {
                    viewModel.retryScanning()
                }
                .buttonStyle(.borderedProminent)

            case .failure:
                Button("再試行") {
                    viewModel.retryScanning()
                }
                .buttonStyle(.borderedProminent)

            case .idle, .scanning:
                EmptyView()
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial)
        .cornerRadius(20)
        .padding()
    }
}

#Preview {
    NavigationStack {
        ScannerScreen()
    }
}
