import AVFoundation
import Vision
import Combine

/// Manages the AVCaptureSession and dispatches video frames to Vision detectors.
/// Replaces the original Python `Capturer` class and `cam_loop` process.
final class CameraManager: NSObject, ObservableObject {
    @Published var isRunning = false
    @Published var permissionGranted = false

    let session = AVCaptureSession()

    /// Pre-configured preview layer — created during setup, reused by views.
    let previewLayer = AVCaptureVideoPreviewLayer()

    /// The orientation to pass to VNImageRequestHandler.
    private(set) var visionOrientation: CGImagePropertyOrientation = .right

    private let videoOutput = AVCaptureVideoDataOutput()
    private let processingQueue = DispatchQueue(label: "com.kieleth.behave.camera", qos: .userInteractive)

    /// Handlers called on each frame with the sample buffer
    var onFrame: ((CMSampleBuffer) -> Void)?

    override init() {
        super.init()
        checkPermission()
    }

    func checkPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            permissionGranted = true
            setupSession()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    self?.permissionGranted = granted
                    if granted { self?.setupSession() }
                }
            }
        default:
            permissionGranted = false
        }
    }

    private func setupSession() {
        session.beginConfiguration()
        session.sessionPreset = .medium

        // Front camera for self-monitoring
        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
              let input = try? AVCaptureDeviceInput(device: camera),
              session.canAddInput(input) else {
            session.commitConfiguration()
            return
        }

        session.addInput(input)

        videoOutput.setSampleBufferDelegate(self, queue: processingQueue)
        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]

        if session.canAddOutput(videoOutput) {
            session.addOutput(videoOutput)
        }

        if let connection = videoOutput.connection(with: .video) {
            connection.isVideoMirrored = true
            visionOrientation = .right
        }

        // Configure preview layer BEFORE session starts
        previewLayer.session = session
        previewLayer.videoGravity = .resizeAspectFill

        session.commitConfiguration()
    }

    func start() {
        guard !session.isRunning else { return }
        processingQueue.async { [weak self] in
            self?.session.startRunning()
            DispatchQueue.main.async { self?.isRunning = true }
        }
    }

    func stop() {
        guard session.isRunning else { return }
        processingQueue.async { [weak self] in
            self?.session.stopRunning()
            DispatchQueue.main.async { self?.isRunning = false }
        }
    }
}

extension CameraManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        onFrame?(sampleBuffer)
    }
}
