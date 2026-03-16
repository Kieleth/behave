import Foundation
import CoreMedia
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
    private var habitClassifier = HabitClassifier()
    private var speechClassifier = SpeechClassifier()

    // Enforcer
    let enforcement = EnforcementEngine()

    // Pomodoro
    let pomodoro = PomodoroTimer()
    @Published var breakSuggestion: BreakSuggestionEngine.Suggestion?
    @Published var isPausedForBreak = false

    // Calibration
    @Published var calibration = PostureClassifier.Calibration()
    @Published var isCalibrated = false

    // Last classification results (for debug/visual feedback)
    @Published var lastPostureResult: PostureClassifier.Result?
    @Published var lastExpressionResult: ExpressionClassifier.Result?
    @Published var lastSpeechResult: SpeechClassifier.Result?
    @Published var lastHabitDetails: String = ""

    // Session tracking
    private var sessionStart: Date?
    private var frameCount = 0
    @Published var processedFrameCount = 0  // visible to debug overlay
    private let processEveryNthFrame = 3  // skip frames for performance, like original `circular_counter`

    // Persistence
    var modelContext: ModelContext?
    private var currentSession: LocalSession?

    // Running score accumulators (averaged at session end)
    private var postureScoreSum: Double = 0
    private var expressionScoreSum: Double = 0
    private var habitScoreSum: Double = 0
    private var speechScoreSum: Double = 0
    private var scoreSampleCount: Int = 0

    private var timer: Timer?

    /// Configure from persisted settings. Call after setting modelContext.
    func loadSettings() {
        guard let ctx = modelContext else { return }
        let descriptor = FetchDescriptor<LocalSettings>()
        if let settings = try? ctx.fetch(descriptor).first {
            enforcement.configure(from: settings)

            // Configure pomodoro from settings
            pomodoro.workDuration = settings.pomodoroWorkMinutes * 60
            pomodoro.shortBreakDuration = settings.pomodoroShortBreakMinutes * 60
            pomodoro.longBreakDuration = settings.pomodoroLongBreakMinutes * 60
            pomodoro.longBreakInterval = settings.pomodoroLongBreakInterval

            // Restore calibration if saved
            if settings.isCalibrated {
                calibration = PostureClassifier.Calibration(
                    noseY: settings.calibrationNoseY,
                    shoulderMidY: settings.calibrationShoulderMidY,
                    headToShoulderRatio: settings.calibrationHeadToShoulderRatio,
                    shoulderAngle: settings.calibrationShoulderAngle,
                    shoulderWidth: settings.calibrationShoulderWidth,
                    faceBBoxHeight: settings.calibrationFaceBBoxHeight,
                    faceBBoxCenterY: settings.calibrationFaceBBoxCenterY
                )
                isCalibrated = true
            }
        }
    }

    /// Start camera + detectors only (no session, no pomodoro).
    /// Used for calibration and preview.
    func startPreview() {
        camera.onFrame = { [weak self] sampleBuffer in
            self?.runDetectors(sampleBuffer)
        }
        camera.start()
    }

    /// Run detectors without classification/enforcement.
    private func runDetectors(_ sampleBuffer: CMSampleBuffer) {
        frameCount += 1
        guard frameCount % processEveryNthFrame == 0 else { return }
        let orientation = camera.visionOrientation
        poseDetector.detect(in: sampleBuffer, orientation: orientation)
        faceDetector.detect(in: sampleBuffer, orientation: orientation)
        handDetector.detect(in: sampleBuffer, orientation: orientation)
        DispatchQueue.main.async { [weak self] in
            self?.processedFrameCount += 1
        }
    }

    func start() {
        guard !isActive else { return }

        sessionStart = Date()
        sessionDuration = 0
        frameCount = 0
        postureScoreSum = 0
        expressionScoreSum = 0
        habitScoreSum = 0
        speechScoreSum = 0
        scoreSampleCount = 0
        enforcement.reset()

        // Create persistent session
        let session = LocalSession(startedAt: Date())
        currentSession = session
        if let ctx = modelContext {
            ctx.insert(session)
            try? ctx.save()
        }

        // Wire alert persistence
        enforcement.onAlert = { [weak self] alert in
            self?.persistAlert(alert)
        }

        // Wire pomodoro phase changes
        pomodoro.onPhaseChange = { [weak self] phase in
            Task { @MainActor in
                self?.handlePhaseChange(phase)
            }
        }

        // Set up frame processing pipeline
        camera.onFrame = { [weak self] sampleBuffer in
            self?.processFrame(sampleBuffer)
        }

        camera.start()
        pomodoro.startWork()
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
        pomodoro.stop()
        timer?.invalidate()
        timer = nil
        isActive = false
        isPausedForBreak = false
        breakSuggestion = nil

        // Finalize and save session
        if let session = currentSession, scoreSampleCount > 0 {
            let count = Double(scoreSampleCount)
            session.end(scores: (
                posture: postureScoreSum / count,
                expression: expressionScoreSum / count,
                habit: habitScoreSum / count,
                speech: speechScoreSum / count
            ))
            try? modelContext?.save()
        }
        currentSession = nil
        enforcement.onAlert = nil
    }

    /// Persist a behavioral alert as a LocalEvent attached to the current session.
    private func persistAlert(_ alert: BehaviorAlert) {
        guard let session = currentSession, let ctx = modelContext else { return }

        let severityString: String
        switch alert.severity {
        case .warning: severityString = "medium"
        case .alert: severityString = "high"
        case .ok: severityString = "low"
        }

        let event = LocalEvent(
            type: "\(alert.behavior)_violation",
            severity: severityString,
            details: "{\"message\":\"\(alert.message)\"}",
            timestamp: alert.timestamp
        )
        event.session = session
        session.events.append(event)
        ctx.insert(event)
        try? ctx.save()
    }

    /// Process a single video frame through the full pipeline.
    /// Runs on the camera processing queue.
    private func processFrame(_ sampleBuffer: CMSampleBuffer) {
        frameCount += 1

        // Skip frames for performance (like original circular_counter)
        guard frameCount % processEveryNthFrame == 0 else { return }

        // Run detectors (all on Neural Engine, fast)
        let orientation = camera.visionOrientation
        poseDetector.detect(in: sampleBuffer, orientation: orientation)
        faceDetector.detect(in: sampleBuffer, orientation: orientation)
        handDetector.detect(in: sampleBuffer, orientation: orientation)

        // Classify + enforce on main thread (reading @Published properties)
        DispatchQueue.main.async { [weak self] in
            self?.classifyAndEnforce()
        }
    }

    private func classifyAndEnforce() {
        // Posture: try body pose first, fall back to face-only
        let postureResult: PostureClassifier.Result?
        if let body = poseDetector.bodyLandmarks {
            postureResult = postureClassifier.classify(landmarks: body, calibration: calibration)
        } else if let face = faceDetector.faceLandmarks {
            postureResult = postureClassifier.classifyFromFace(face, calibration: calibration)
        } else {
            postureResult = nil
        }

        let expressionResult = faceDetector.faceLandmarks.map {
            expressionClassifier.classify(faceLandmarks: $0)
        }
        lastExpressionResult = expressionResult

        // Store for debug overlay
        lastPostureResult = postureResult

        let habitResult = habitClassifier.classify(
            hands: handDetector.hands,
            face: faceDetector.faceLandmarks
        )
        lastHabitDetails = habitResult.details

        let speechResult = speechClassifier.classify(
            words: speechDetector.recentWords,
            sessionDurationSeconds: sessionDuration
        )
        lastSpeechResult = speechResult

        enforcement.process(
            posture: postureResult,
            expression: expressionResult,
            habits: habitResult,
            speech: speechResult
        )

        // Accumulate scores for session average
        postureScoreSum += enforcement.postureStatus.score
        expressionScoreSum += enforcement.expressionStatus.score
        habitScoreSum += enforcement.habitStatus.score
        speechScoreSum += enforcement.speechStatus.score
        scoreSampleCount += 1
    }

    // MARK: - Pomodoro integration

    private func handlePhaseChange(_ phase: PomodoroTimer.Phase) {
        switch phase {
        case .shortBreak, .longBreak:
            // Pause monitoring, generate break suggestion
            isPausedForBreak = true
            camera.stop()
            speechDetector.stop()
            breakSuggestion = BreakSuggestionEngine.suggest(
                postureScore: enforcement.postureStatus.score,
                expressionScore: enforcement.expressionStatus.score,
                habitScore: enforcement.habitStatus.score,
                speechScore: enforcement.speechStatus.score
            )
        case .work:
            // Resume monitoring
            isPausedForBreak = false
            breakSuggestion = nil
            camera.start()
        case .idle:
            break
        }
    }

    // MARK: - Calibration (auto-adjust protocol)

    @Published var calibrationSnapshots: [BodyLandmarks] = []
    let calibrationTarget = 5  // reduced — 5 snapshots is enough

    /// Whether the detectors can see the user at all.
    var isUserDetected: Bool {
        faceDetector.faceLandmarks != nil || poseDetector.bodyLandmarks != nil
    }

    func startCalibration() {
        calibrationSnapshots = []
    }

    func captureCalibrationSnapshot() {
        // Try body pose first (best calibration data)
        if let landmarks = poseDetector.bodyLandmarks {
            calibrationSnapshots.append(landmarks)
        }
        // Fallback: build BodyLandmarks from face data
        // (face nose position + estimated shoulder positions)
        else if let face = faceDetector.faceLandmarks, let nose = face.nose?.first {
            let box = face.boundingBox
            // Estimate shoulder positions from face bounding box
            let shoulderY = box.maxY + box.height * 0.6
            let leftShoulder = CGPoint(x: box.minX - box.width * 0.3, y: shoulderY)
            let rightShoulder = CGPoint(x: box.maxX + box.width * 0.3, y: shoulderY)
            let nosePoint = CGPoint(x: box.midX, y: nose.y)

            let fallback = BodyLandmarks(
                nose: nosePoint,
                leftShoulder: leftShoulder,
                rightShoulder: rightShoulder
            )
            calibrationSnapshots.append(fallback)
        }

        if calibrationSnapshots.count >= calibrationTarget {
            calibration = PostureClassifier.calibrate(
                from: calibrationSnapshots,
                face: faceDetector.faceLandmarks
            )
            isCalibrated = true
            saveCalibration()
        }
    }

    /// Persist calibration to LocalSettings so it survives app restarts.
    private func saveCalibration() {
        guard let ctx = modelContext else { return }
        let descriptor = FetchDescriptor<LocalSettings>()
        let settings: LocalSettings
        if let existing = try? ctx.fetch(descriptor).first {
            settings = existing
        } else {
            settings = LocalSettings()
            ctx.insert(settings)
        }
        settings.calibrationNoseY = calibration.noseY
        settings.calibrationShoulderMidY = calibration.shoulderMidY
        settings.calibrationHeadToShoulderRatio = calibration.headToShoulderRatio
        settings.calibrationShoulderAngle = calibration.shoulderAngle
        settings.calibrationShoulderWidth = calibration.shoulderWidth
        settings.calibrationFaceBBoxHeight = calibration.faceBBoxHeight
        settings.calibrationFaceBBoxCenterY = calibration.faceBBoxCenterY
        settings.isCalibrated = true
        try? ctx.save()
    }
}
