import AVFoundation
import UIKit

enum AVFoundationBarcodeCaptureError: Error {
    case cameraUnavailable
    case inputCreationFailed(underlying: Error)
}

final class AVFoundationBarcodeCaptureSource: NSObject, BarcodeCaptureSource {
    weak var delegate: BarcodeCaptureSourceDelegate?

    private let session = AVCaptureSession()
    private let metadataOutput = AVCaptureMetadataOutput()
    private var previewLayer: AVCaptureVideoPreviewLayer?

    func configure(in parent: UIViewController) throws {
        if previewLayer == nil {
            try configureSession()
            let layer = AVCaptureVideoPreviewLayer(session: session)
            layer.videoGravity = .resizeAspectFill
            layer.frame = parent.view.bounds
            parent.view.layer.insertSublayer(layer, at: 0)
            previewLayer = layer
        }
    }

    func updateLayout(in parent: UIViewController) {
        previewLayer?.frame = parent.view.bounds
    }

    func startScanning() throws {
        guard !session.isRunning else { return }
        session.startRunning()
    }

    func stopScanning() {
        guard session.isRunning else { return }
        session.stopRunning()
    }

    private func configureSession() throws {
        session.beginConfiguration()
        session.sessionPreset = .high

        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            session.commitConfiguration()
            throw AVFoundationBarcodeCaptureError.cameraUnavailable
        }

        do {
            let input = try AVCaptureDeviceInput(device: device)
            if session.canAddInput(input) {
                session.addInput(input)
            }
        } catch {
            session.commitConfiguration()
            throw AVFoundationBarcodeCaptureError.inputCreationFailed(underlying: error)
        }

        if session.canAddOutput(metadataOutput) {
            session.addOutput(metadataOutput)
            metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
            metadataOutput.metadataObjectTypes = [.ean13, .ean8, .upce]
        }

        session.commitConfiguration()
    }
}

extension AVFoundationBarcodeCaptureSource: AVCaptureMetadataOutputObjectsDelegate {
    func metadataOutput(
        _ output: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from connection: AVCaptureConnection
    ) {
        for rawObject in metadataObjects {
            guard let codeObject = rawObject as? AVMetadataMachineReadableCodeObject else { continue }
            guard let stringValue = codeObject.stringValue else { continue }
            delegate?.barcodeCaptureSource(self, didDetectRawValue: stringValue)
        }
    }
}
