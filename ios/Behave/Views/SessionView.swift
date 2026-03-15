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
                            PostureFeedbackOverlay(orchestrator: orchestrator)
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

// MARK: - Posture Visual Feedback

struct PostureFeedbackOverlay: View {
    @ObservedObject var orchestrator: SessionOrchestrator

    var body: some View {
        VStack {
            Spacer()

            if let p = orchestrator.lastPostureResult, !p.isGood {
                HStack(spacing: 8) {
                    Image(systemName: "figure.stand")
                        .font(.title3)
                    Text(p.details.capitalized)
                        .font(.subheadline.bold())
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(.red.opacity(0.85), in: Capsule())
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .padding(.bottom, 100)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: orchestrator.lastPostureResult?.isGood)
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
                if let nose = face.nose {
                    FaceLandmarkDots(points: nose, size: size, imageAspect: imgAspect, color: .yellow)
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

            for (_, point) in points {
                let rect = CGRect(x: point.x - 4, y: point.y - 4, width: 8, height: 8)
                context.fill(Path(ellipseIn: rect), with: .color(color))
            }

            let connections: [(VNHumanBodyPoseObservation.JointName, VNHumanBodyPoseObservation.JointName)] = [
                (.nose, .neck),
                (.neck, .leftShoulder), (.neck, .rightShoulder),
                (.leftShoulder, .leftElbow), (.leftElbow, .leftWrist),
                (.rightShoulder, .rightElbow), (.rightElbow, .rightWrist),
                (.neck, .leftHip), (.neck, .rightHip),
            ]

            for (from, to) in connections {
                if let p1 = points[from], let p2 = points[to] {
                    var path = Path()
                    path.move(to: p1)
                    path.addLine(to: p2)
                    context.stroke(path, with: .color(color.opacity(0.6)), lineWidth: 2)
                }
            }
        }
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
