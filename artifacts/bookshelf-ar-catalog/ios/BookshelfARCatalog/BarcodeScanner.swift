import AVFoundation
import SwiftUI
import UIKit

struct BarcodeScannerView: UIViewControllerRepresentable {
    var onCode: (String) -> Void
    var onDenied: () -> Void

    func makeUIViewController(context: Context) -> BarcodeScannerController {
        let controller = BarcodeScannerController()
        controller.onCode = onCode
        controller.onDenied = onDenied
        return controller
    }

    func updateUIViewController(_ controller: BarcodeScannerController, context: Context) {
        controller.onCode = onCode
        controller.onDenied = onDenied
    }
}

final class BarcodeScannerController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    var onCode: ((String) -> Void)?
    var onDenied: (() -> Void)?

    private let session = AVCaptureSession()
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var hasDeliveredCode = false
    private var isConfigured = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        checkPermissionAndStart()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
        if let connection = previewLayer?.connection, connection.isVideoOrientationSupported {
            connection.videoOrientation = currentVideoOrientation()
        }
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        coordinator.animate(alongsideTransition: { _ in
            if let connection = self.previewLayer?.connection, connection.isVideoOrientationSupported {
                connection.videoOrientation = self.currentVideoOrientation()
            }
            self.previewLayer?.frame = self.view.bounds
        })
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        hasDeliveredCode = false
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        if status == .authorized {
            if isConfigured {
                if !session.isRunning { session.startRunning() }
            } else {
                configureSession()
            }
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if session.isRunning { session.stopRunning() }
    }

    private func checkPermissionAndStart() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            configureSession()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    guard let self else { return }
                    granted ? self.configureSession() : self.onDenied?()
                }
            }
        default:
            DispatchQueue.main.async { [weak self] in
                self?.onDenied?()
            }
        }
    }

    private func configureSession() {
        guard !session.isRunning else { return }

        session.beginConfiguration()
        session.sessionPreset = .high
        defer { session.commitConfiguration() }

        let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) ?? AVCaptureDevice.default(for: .video)

        guard let camera,
              let input = try? AVCaptureDeviceInput(device: camera),
              session.canAddInput(input) else {
            DispatchQueue.main.async { [weak self] in self?.onDenied?() }
            return
        }

        // Optional: improve focus behavior for scanning
        if camera.isFocusModeSupported(.continuousAutoFocus) {
            do {
                try camera.lockForConfiguration()
                camera.focusMode = .continuousAutoFocus
                camera.unlockForConfiguration()
            } catch {
                // Ignore focus configuration errors
            }
        }

        session.addInput(input)

        let output = AVCaptureMetadataOutput()
        guard session.canAddOutput(output) else {
            DispatchQueue.main.async { [weak self] in self?.onDenied?() }
            return
        }
        session.addOutput(output)
        output.setMetadataObjectsDelegate(self, queue: .main)
        let desiredTypes: [AVMetadataObject.ObjectType] = [.ean13, .ean8, .upce, .code128]
        output.metadataObjectTypes = desiredTypes.filter { output.availableMetadataObjectTypes.contains($0) }

        if previewLayer == nil {
            let preview = AVCaptureVideoPreviewLayer(session: session)
            preview.videoGravity = .resizeAspectFill
            previewLayer = preview
            view.layer.insertSublayer(preview, at: 0)
        }

        isConfigured = true
        session.startRunning()
    }

    private func currentVideoOrientation() -> AVCaptureVideoOrientation {
        switch view.window?.windowScene?.interfaceOrientation {
        case .landscapeLeft: return .landscapeLeft
        case .landscapeRight: return .landscapeRight
        case .portraitUpsideDown: return .portraitUpsideDown
        default: return .portrait
        }
    }

    func metadataOutput(
        _ output: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from connection: AVCaptureConnection
    ) {
        guard !hasDeliveredCode,
              let object = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              let value = object.stringValue else { return }
        hasDeliveredCode = true
        session.stopRunning()
        onCode?(value)
    }
}
