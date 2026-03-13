import Foundation
import Combine
import SwiftData

/// Orchestrates the detection pipeline: camera → detectors → classifiers → enforcers.
/// This is the heart of Behave — the modern equivalent of the original `cam_loop` + `callback_update_frame`.
@MainActor
final class SessionOrchestrator: ObservableObject {
    @Published var isActive = false
    @Published var sessionDuration: TimeInterval = 0

    // Detectors
    let camera = CameraManager()
    let poseDetector = PoseDetector()
    let faceDetector = FaceDetector()
    let handDetector = HandDetector()
    let speechDetector = SpeechDetector()

    // Classifiers
    private let postureClassifier = PostureClassifier()
    private let expressionClassifier = ExpressionClassifier()
    private let habitClassifier = HabitClassifier()
    private let speechClassifier = SpeechClassifier()

    // Enforcer
    let enforcement = EnforcementEngine()

    // Calibration
    @Published var calibration = PostureClassifier.Calibration()
    @Published var isCalibrated = false

    // Session tracking
    private var sessionStart: Date?
    private var frameCount = 0
    private let processEveryNthFrame = 3  // skip frames for performance, like original `circular_counter`

    private var timer: Timer?

    func start() {
        guard !isActive else { return }

        sessionStart = Date()
        sessionDuration = 0
        frameCount = 0
        enforcement.reset()

        // Set up frame processing pipeline
        camera.onFrame = { [weak self] sampleBuffer in
            self?.processFrame(sampleBuffer)
        }

        camera.start()
        isActive = true

        // Update duration timer
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self, let start = self.sessionStart else { return }
            Task { @MainActor in
                self.sessionDuration = Date().timeIntervalSince(start)
            }
        }
    }

    func stop() {
        camera.stop()
        speechDetector.stop()
        timer?.invalidate()
        timer = nil
        isActive = false
    }

    /// Process a single video frame through the full pipeline.
    /// Runs on the camera processing queue.
    private func processFrame(_ sampleBuffer: CMSampleBuffer) {
        frameCount += 1

        // Skip frames for performance (like original circular_counter)
        guard frameCount % processEveryNthFrame == 0 else { return }

        // Run detectors (all on Neural Engine, fast)
        poseDetector.detect(in: sampleBuffer)
        faceDetector.detect(in: sampleBuffer)
        handDetector.detect(in: sampleBuffer)

        // Classify + enforce on main thread (reading @Published properties)
        DispatchQueue.main.async { [weak self] in
            self?.classifyAndEnforce()
        }
    }

    private func classifyAndEnforce() {
        let postureResult = poseDetector.bodyLandmarks.map {
            postureClassifier.classify(landmarks: $0, calibration: calibration)
        }

        let expressionResult = faceDetector.faceLandmarks.map {
            expressionClassifier.classify(faceLandmarks: $0)
        }

        let habitResult = habitClassifier.classify(
            hands: handDetector.hands,
            face: faceDetector.faceLandmarks
        )

        let speechResult = speechClassifier.classify(
            words: speechDetector.recentWords,
            sessionDurationSeconds: sessionDuration
        )

        enforcement.process(
            posture: postureResult,
            expression: expressionResult,
            habits: habitResult,
            speech: speechResult
        )
    }

    // MARK: - Calibration (auto-adjust protocol)

    @Published var calibrationSnapshots: [BodyLandmarks] = []
    let calibrationTarget = 10

    func startCalibration() {
        calibrationSnapshots = []
    }

    func captureCalibrationSnapshot() {
        guard let landmarks = poseDetector.bodyLandmarks else { return }
        calibrationSnapshots.append(landmarks)

        if calibrationSnapshots.count >= calibrationTarget {
            calibration = PostureClassifier.calibrate(from: calibrationSnapshots)
            isCalibrated = true
        }
    }
}
