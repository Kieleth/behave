import SwiftUI
import SwiftData
import AVFoundation
import Vision

/// Main session screen: camera preview with detection overlays.
struct SessionView: View {
    @StateObject private var orchestrator = SessionOrchestrator()
    @Environment(\.modelContext) private var modelContext
    @State private var showCalibration = false

    var body: some View {
        ZStack {
            // Camera preview — uses the pre-created layer from CameraManager
            CameraPreviewView(previewLayer: orchestrator.camera.previewLayer)
                .ignoresSafeArea()

                    if orchestrator.isActive && !showCalibration {
                        // Detection overlays (hidden during breaks and calibration)
                        if !orchestrator.isPausedForBreak {
                            DetectionOverlay(orchestrator: orchestrator)
                            BehaviorFeedbackOverlay(orchestrator: orchestrator)
                        }

                // Break overlay
                if orchestrator.isPausedForBreak,
                   let suggestion = orchestrator.breakSuggestion {
                    BreakView(
                        suggestion: suggestion,
                        pomodoro: orchestrator.pomodoro,
                        onSkip: { orchestrator.pomodoro.skip() }
                    )
                }
            }

            // Calibration overlay — inline, no sheet/cover
            if showCalibration {
                CalibrationOverlay(
                    orchestrator: orchestrator,
                    onDone: { showCalibration = false }
                )
            }

            // HUD (hidden during calibration)
            if !showCalibration {
                VStack(spacing: 0) {
                        if orchestrator.isActive {
                            HStack {
                                StatusBar(orchestrator: orchestrator)
                                Spacer()
                                PomodoroOverlay(pomodoro: orchestrator.pomodoro)
                            }
                            .padding(.horizontal)
                            .padding(.top, 8)

                            HStack {
                                BodyTrackingBadge(orchestrator: orchestrator)
                                Spacer()
                            }
                            .padding(.horizontal)
                            .padding(.top, 4)
                        }

                    // Debug
                    HStack {
                        DebugOverlay(orchestrator: orchestrator)
                        Spacer()
                    }
                    .padding(.horizontal, 8)
                    .padding(.top, 8)

                    Spacer()

                    // Idle prompt
                    if !orchestrator.isActive {
                        VStack(spacing: 8) {
                            Text("Place phone next to laptop")
                                .font(.headline)
                                .foregroundStyle(.white)
                            Text("Tap play to start monitoring")
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.6))
                        }
                        Spacer()
                    }

                    // Controls
                    ControlBar(orchestrator: orchestrator, showCalibration: $showCalibration)
                        .padding(.horizontal)
                        .padding(.bottom, 8)
                }
            }
        }
        .task {
            orchestrator.modelContext = modelContext
            orchestrator.loadSettings()
            orchestrator.startPreview()
        }
        .onChange(of: orchestrator.isActive) { _, active in
            UIApplication.shared.isIdleTimerDisabled = active
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
        }
    }
}

// MARK: - Camera Preview (uses pre-created layer from CameraManager)

struct CameraPreviewView: UIViewRepresentable {
    let previewLayer: AVCaptureVideoPreviewLayer

    func makeUIView(context: Context) -> PreviewContainerView {
        let view = PreviewContainerView(previewLayer: previewLayer)
        return view
    }

    func updateUIView(_ uiView: PreviewContainerView, context: Context) {
        // Force layout update
        uiView.setNeedsLayout()
    }

    class PreviewContainerView: UIView {
        let previewLayer: AVCaptureVideoPreviewLayer

        init(previewLayer: AVCaptureVideoPreviewLayer) {
            self.previewLayer = previewLayer
            super.init(frame: .zero)
            layer.addSublayer(previewLayer)
        }

        required init?(coder: NSCoder) { fatalError() }

        override func layoutSubviews() {
            super.layoutSubviews()
            previewLayer.frame = bounds
        }
    }
}

// MARK: - Debug Overlay

struct DebugOverlay: View {
    @ObservedObject var orchestrator: SessionOrchestrator

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("DEBUG").font(.caption2.bold()).foregroundStyle(.yellow)
            Text("Cam: \(orchestrator.camera.isRunning ? "ON" : "OFF")  Fr: \(orchestrator.processedFrameCount)")

            if let face = orchestrator.faceDetector.faceLandmarks {
                let b = face.boundingBox
                Text("Face: \(f(b.width))x\(f(b.height))")
                    .foregroundStyle(.green)
            } else {
                Text("Face: ---").foregroundStyle(.red)
            }

            if let body = orchestrator.poseDetector.bodyLandmarks {
                Text("Body: \(body.allPoints.count) joints").foregroundStyle(.green)
            } else {
                Text("Body: ---").foregroundStyle(.red)
            }

            Text("Hands: \(orchestrator.handDetector.hands.count)")

            // Posture debug
            if let p = orchestrator.lastPostureResult {
                let color: Color = p.isGood ? .green : .red
                Text("Posture: \(p.details)").foregroundStyle(color)
                Text("  tilt:\(f2(p.shoulderTilt)) drop:\(f2(p.headDropRatio)) shrug:\(f2(p.shoulderShrug))")
                Text("  src: \(String(describing: p.source))")
            }

            Text("Cal: \(orchestrator.isCalibrated ? "YES" : "NO")")

            // Expression/gaze debug
            if let e = orchestrator.lastExpressionResult {
                Text("Eyes: \(f2(e.eyeOpenness)) \(e.isSquinting ? "SQUINT" : "") \(e.gazeDirection.rawValue)")
                    .foregroundStyle(e.isLookingAway ? .orange : .white)
            }

            // Speech debug
            if let s = orchestrator.lastSpeechResult {
                let speaking = s.isSpeaking ? "SPEAKING" : "silent"
                Text("Speech: \(speaking) \(Int(s.wordsPerMinute))wpm")
                    .foregroundStyle(s.isSpeaking ? .cyan : .white)
                if s.shouldBreathe {
                    Text("  BREATHE!").foregroundStyle(.red).bold()
                }
            }

            // Habit debug
            if !orchestrator.lastHabitDetails.isEmpty {
                Text("Habits: \(orchestrator.lastHabitDetails)")
                    .foregroundStyle(orchestrator.lastHabitDetails == "No habits detected" ? .white : .orange)
            }
        }
        .font(.caption2.monospaced())
        .foregroundStyle(.white)
        .padding(6)
        .background(.black.opacity(0.75), in: RoundedRectangle(cornerRadius: 6))
    }

    private func f(_ v: CGFloat) -> String { String(format: "%.2f", v) }
    private func f2(_ v: Double) -> String { String(format: "%.2f", v) }
}

// MARK: - Behavioral Feedback Overlay

struct BehaviorFeedbackOverlay: View {
    @ObservedObject var orchestrator: SessionOrchestrator

    var body: some View {
        VStack(spacing: 8) {
            Spacer()

            // Breathing reminder (highest priority — show first)
            if let s = orchestrator.lastSpeechResult, s.shouldBreathe {
                feedbackBanner(
                    icon: "wind",
                    text: s.continuousSpeakingSeconds > 30 ? "Pause and breathe" : "Breathe before speaking",
                    color: .blue
                )
            }

            // Gaze — only while speaking
            if let e = orchestrator.lastExpressionResult, let s = orchestrator.lastSpeechResult,
               s.isSpeaking && e.isLookingAway {
                feedbackBanner(
                    icon: "eye.slash",
                    text: "Look at the screen",
                    color: .orange
                )
            }

            // Squinting — coaching card (not just while speaking — this is a general habit)
            if let e = orchestrator.lastExpressionResult, e.isSquinting {
                squintingCoachingCard
            }

            // Posture
            if let p = orchestrator.lastPostureResult, !p.isGood {
                feedbackBanner(
                    icon: "figure.stand",
                    text: p.details.capitalized,
                    color: .red
                )
            }

            // Habits
            if orchestrator.lastHabitDetails != "No habits detected" && !orchestrator.lastHabitDetails.isEmpty {
                feedbackBanner(
                    icon: "hand.raised",
                    text: orchestrator.lastHabitDetails.capitalized,
                    color: .purple
                )
            }
        }
        .padding(.bottom, 100)
        .animation(.easeInOut(duration: 0.3), value: orchestrator.lastPostureResult?.isGood)
        .animation(.easeInOut(duration: 0.3), value: orchestrator.lastExpressionResult?.isLookingAway)
        .animation(.easeInOut(duration: 0.3), value: orchestrator.lastSpeechResult?.shouldBreathe)
    }

    /// Stanford physiological sigh coaching card for squinting
    private var squintingCoachingCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "eye.trianglebadge.exclamationmark")
                    .foregroundStyle(.yellow)
                Text("You're squinting")
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
            }

            Text("Your body is manifesting tension through your eyes. Try a physiological sigh:")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.8))

            VStack(alignment: .leading, spacing: 4) {
                breathStep("1", "Double inhale through your nose (short + deep)")
                breathStep("2", "Long slow exhale through your mouth")
                breathStep("3", "Repeat 2-3 times")
            }

            Text("This activates your parasympathetic nervous system and releases tension within seconds.")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.5))
                .italic()

            Text("Huberman Lab, Stanford School of Medicine")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.3))
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.black.opacity(0.85), in: RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal, 16)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    private func breathStep(_ num: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(num)
                .font(.caption.bold())
                .foregroundStyle(.yellow)
                .frame(width: 16)
            Text(text)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.9))
        }
    }

    private func feedbackBanner(icon: String, text: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon).font(.subheadline)
            Text(text).font(.subheadline.bold())
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(color.opacity(0.85), in: Capsule())
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}

// MARK: - Detection Overlay

struct DetectionOverlay: View {
    @ObservedObject var orchestrator: SessionOrchestrator

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            let imgAspect = orchestrator.camera.imageAspectRatio

            if let body = orchestrator.poseDetector.bodyLandmarks {
                SkeletonView(landmarks: body, size: size, imageAspect: imgAspect, status: orchestrator.enforcement.postureStatus)
            } else if let face = orchestrator.faceDetector.faceLandmarks {
                // Inferred skeleton when body pose not available
                InferredSkeletonView(
                    face: face, screenSize: size, imageAspect: imgAspect,
                    status: orchestrator.enforcement.postureStatus,
                    taughtLeftShoulder: orchestrator.taughtLeftShoulder,
                    taughtRightShoulder: orchestrator.taughtRightShoulder
                )
            }

            if let face = orchestrator.faceDetector.faceLandmarks {
                let rect = LandmarkMath.visionToScreen(face.boundingBox, screenSize: size, imageAspect: imgAspect)
                let color = statusColor(orchestrator.enforcement.expressionStatus)

                RoundedRectangle(cornerRadius: 8)
                    .stroke(color, lineWidth: 2)
                    .frame(width: rect.width * 1.2, height: rect.height * 1.2)
                    .position(x: rect.midX, y: rect.midY)

                if let leftEye = face.leftEye {
                    FaceLandmarkDots(points: leftEye, size: size, imageAspect: imgAspect, color: .cyan)
                }
                if let rightEye = face.rightEye {
                    FaceLandmarkDots(points: rightEye, size: size, imageAspect: imgAspect, color: .cyan)
                }
                if let outerLips = face.outerLips {
                    FaceLandmarkDots(points: outerLips, size: size, imageAspect: imgAspect, color: .pink)
                }
            }

            ForEach(Array(orchestrator.handDetector.hands.enumerated()), id: \.offset) { _, hand in
                ForEach(Array(hand.fingertips.enumerated()), id: \.offset) { _, tip in
                    let point = LandmarkMath.visionToScreen(tip, screenSize: size, imageAspect: imgAspect)
                    Circle()
                        .fill(statusColor(orchestrator.enforcement.habitStatus))
                        .frame(width: 8, height: 8)
                        .position(point)
                }
            }
        }
    }

    private func statusColor(_ status: BehaviorStatus) -> Color {
        switch status {
        case .ok: return .green
        case .warning: return .yellow
        case .alert: return .red
        }
    }
}

// MARK: - Skeleton View

struct SkeletonView: View {
    let landmarks: BodyLandmarks
    let size: CGSize
    let imageAspect: CGFloat
    let status: BehaviorStatus

    private var color: Color {
        switch status {
        case .ok: return .green
        case .warning: return .yellow
        case .alert: return .red
        }
    }

    var body: some View {
        Canvas { context, _ in
            let points = landmarks.allPoints.mapValues { LandmarkMath.visionToScreen($0, screenSize: size, imageAspect: imageAspect) }

            // Draw bone connections with thicker lines
            let connections: [(VNHumanBodyPoseObservation.JointName, VNHumanBodyPoseObservation.JointName)] = [
                (.nose, .neck),
                (.neck, .leftShoulder), (.neck, .rightShoulder),
                (.leftShoulder, .leftElbow), (.leftElbow, .leftWrist),
                (.rightShoulder, .rightElbow), (.rightElbow, .rightWrist),
                (.neck, .leftHip), (.neck, .rightHip),
                (.leftHip, .rightHip),
            ]

            for (from, to) in connections {
                if let p1 = points[from], let p2 = points[to] {
                    var path = Path()
                    path.move(to: p1)
                    path.addLine(to: p2)
                    context.stroke(path, with: .color(color.opacity(0.7)), lineWidth: 3)
                }
            }

            // Draw shoulder line prominently (thick, dashed when tilted)
            if let ls = points[.leftShoulder], let rs = points[.rightShoulder] {
                var shoulderPath = Path()
                shoulderPath.move(to: ls)
                shoulderPath.addLine(to: rs)
                context.stroke(shoulderPath, with: .color(color), style: StrokeStyle(lineWidth: 4, lineCap: .round))

                // Shoulder dots (larger)
                for p in [ls, rs] {
                    let rect = CGRect(x: p.x - 8, y: p.y - 8, width: 16, height: 16)
                    context.fill(Path(ellipseIn: rect), with: .color(color))
                    let inner = CGRect(x: p.x - 4, y: p.y - 4, width: 8, height: 8)
                    context.fill(Path(ellipseIn: inner), with: .color(.white))
                }
            }

            // Draw joints
            for (name, point) in points where name != .leftShoulder && name != .rightShoulder {
                let rect = CGRect(x: point.x - 5, y: point.y - 5, width: 10, height: 10)
                context.fill(Path(ellipseIn: rect), with: .color(color))
            }

            // Head marker (nose = head position)
            if let nose = points[.nose] {
                let headRect = CGRect(x: nose.x - 10, y: nose.y - 10, width: 20, height: 20)
                context.stroke(Path(ellipseIn: headRect), with: .color(color), lineWidth: 2)
            }

            // Spine line: nose → neck → hip center (shows alignment)
            if let nose = points[.nose], let neck = points[.neck] {
                var spinePath = Path()
                spinePath.move(to: nose)
                spinePath.addLine(to: neck)
                if let lh = points[.leftHip], let rh = points[.rightHip] {
                    let hipCenter = CGPoint(x: (lh.x + rh.x) / 2, y: (lh.y + rh.y) / 2)
                    spinePath.addLine(to: hipCenter)
                }
                context.stroke(spinePath, with: .color(color.opacity(0.5)),
                              style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
            }
        }
    }
}

// MARK: - Body Tracking Status Badge

struct BodyTrackingBadge: View {
    @ObservedObject var orchestrator: SessionOrchestrator

    var body: some View {
        let hasBody = orchestrator.poseDetector.bodyLandmarks != nil
        let hasFace = orchestrator.faceDetector.faceLandmarks != nil

        HStack(spacing: 6) {
            if hasBody {
                Image(systemName: "figure.arms.open").foregroundStyle(.green)
                Text("Skeleton: detected").font(.caption2).foregroundStyle(.green)
            } else if hasFace {
                Image(systemName: "figure.stand").foregroundStyle(.cyan)
                Text("Skeleton: inferred").font(.caption2).foregroundStyle(.cyan)
            } else {
                Image(systemName: "figure.stand").foregroundStyle(.gray)
                Text("No tracking").font(.caption2).foregroundStyle(.gray)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(.ultraThinMaterial, in: Capsule())
    }
}

// MARK: - Status Bar

struct StatusBar: View {
    @ObservedObject var orchestrator: SessionOrchestrator
    var body: some View {
        HStack(spacing: 16) {
            StatusPill(label: "Posture", status: orchestrator.enforcement.postureStatus)
            StatusPill(label: "Face", status: orchestrator.enforcement.expressionStatus)
            StatusPill(label: "Habits", status: orchestrator.enforcement.habitStatus)
            StatusPill(label: "Speech", status: orchestrator.enforcement.speechStatus)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}

struct StatusPill: View {
    let label: String
    let status: BehaviorStatus
    private var color: Color {
        switch status {
        case .ok: return .green
        case .warning: return .yellow
        case .alert: return .red
        }
    }
    var body: some View {
        VStack(spacing: 2) {
            Circle().fill(color).frame(width: 10, height: 10)
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
    }
}

// MARK: - Control Bar

struct ControlBar: View {
    @ObservedObject var orchestrator: SessionOrchestrator
    @Binding var showCalibration: Bool

    var body: some View {
        HStack(spacing: 24) {
            Button {
                showCalibration = true
            } label: {
                VStack {
                    Image(systemName: "scope").font(.title2)
                    Text("Calibrate").font(.caption2)
                }
            }
            .foregroundStyle(.white)
            .disabled(orchestrator.isActive)

            Spacer()

            if orchestrator.isActive {
                Text(formatDuration(orchestrator.sessionDuration))
                    .font(.system(.title3, design: .monospaced))
                    .foregroundStyle(.white)
            }

            Spacer()

            Button {
                if orchestrator.isActive { orchestrator.stop() }
                else { orchestrator.start() }
            } label: {
                Circle()
                    .fill(orchestrator.isActive ? .red : .green)
                    .frame(width: 64, height: 64)
                    .overlay {
                        Image(systemName: orchestrator.isActive ? "stop.fill" : "play.fill")
                            .font(.title2).foregroundStyle(.white)
                    }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%02d:%02d", mins, secs)
    }
}
