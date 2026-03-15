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
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                if orchestrator.camera.permissionGranted {
                    // Camera preview — always visible
                    CameraPreviewView(session: orchestrator.camera.session)
                        .ignoresSafeArea()

                    if orchestrator.isActive {
                        // Detection overlays (hidden during breaks)
                        if !orchestrator.isPausedForBreak {
                            DetectionOverlay(orchestrator: orchestrator)
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

                    // HUD: status + debug + controls
                    VStack(spacing: 0) {
                        // Status bar (only when active)
                        if orchestrator.isActive {
                            HStack {
                                StatusBar(orchestrator: orchestrator)
                                Spacer()
                                PomodoroOverlay(pomodoro: orchestrator.pomodoro)
                            }
                            .padding(.horizontal)
                            .padding(.top, 8)
                        }

                        // Debug — always visible, top-left
                        HStack {
                            DebugOverlay(orchestrator: orchestrator)
                            Spacer()
                        }
                        .padding(.horizontal, 8)
                        .padding(.top, 8)

                        Spacer()

                        // Idle state prompt
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
                } else {
                    VStack(spacing: 16) {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 48))
                            .foregroundStyle(.secondary)
                        Text("Camera access required")
                            .font(.headline)
                        Text("Behave needs camera access to analyze your posture and habits.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                        Button("Open Settings") {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()
                }
            }
            .navigationTitle("")
            .navigationBarHidden(true)
            .fullScreenCover(isPresented: $showCalibration) {
                CalibrationView(orchestrator: orchestrator)
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
}

// MARK: - Debug Overlay (always visible)

struct DebugOverlay: View {
    @ObservedObject var orchestrator: SessionOrchestrator

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("DEBUG").font(.caption2.bold()).foregroundStyle(.yellow)

            Text("Cam: \(orchestrator.camera.isRunning ? "ON" : "OFF")  Fr: \(orchestrator.processedFrameCount)")

            let raw = orchestrator.faceDetector.rawBoundingBox
            if raw != .zero {
                Text("Raw: (\(f(raw.midX)),\(f(raw.midY)))")
                if let face = orchestrator.faceDetector.faceLandmarks {
                    let b = face.boundingBox
                    Text("Box: (\(f(b.midX)),\(f(b.midY)))")
                        .foregroundStyle(.green)
                }
            } else {
                Text("Face: ---").foregroundStyle(.red)
            }

            if let body = orchestrator.poseDetector.bodyLandmarks {
                Text("Body: \(body.allPoints.count) joints").foregroundStyle(.green)
            } else {
                Text("Body: ---").foregroundStyle(.red)
            }

            Text("Hands: \(orchestrator.handDetector.hands.count)")

        }
        .font(.caption2.monospaced())
        .foregroundStyle(.white)
        .padding(6)
        .background(.black.opacity(0.75), in: RoundedRectangle(cornerRadius: 6))
    }

    private func f(_ v: CGFloat) -> String { String(format: "%.2f", v) }
}

// MARK: - Camera Preview (UIViewControllerRepresentable — proven approach)

struct CameraPreviewView: UIViewControllerRepresentable {
    let session: AVCaptureSession

    func makeUIViewController(context: Context) -> PreviewViewController {
        let vc = PreviewViewController()
        vc.session = session
        return vc
    }

    func updateUIViewController(_ uiViewController: PreviewViewController, context: Context) {
        uiViewController.session = session
    }

    class PreviewViewController: UIViewController {
        var session: AVCaptureSession? {
            didSet { (view.layer.sublayers?.first as? AVCaptureVideoPreviewLayer)?.session = session }
        }

        override func viewDidLoad() {
            super.viewDidLoad()
            let previewLayer = AVCaptureVideoPreviewLayer()
            previewLayer.session = session
            previewLayer.videoGravity = .resizeAspectFill
            view.layer.addSublayer(previewLayer)
        }

        override func viewDidLayoutSubviews() {
            super.viewDidLayoutSubviews()
            if let previewLayer = view.layer.sublayers?.first as? AVCaptureVideoPreviewLayer {
                previewLayer.frame = view.bounds
            }
        }
    }
}

// MARK: - Detection Overlay

struct DetectionOverlay: View {
    @ObservedObject var orchestrator: SessionOrchestrator

    var body: some View {
        GeometryReader { geo in
            let size = geo.size

            // Skeleton overlay
            if let body = orchestrator.poseDetector.bodyLandmarks {
                SkeletonView(landmarks: body, size: size, status: orchestrator.enforcement.postureStatus)
            }

            // Face bounding box + landmarks
            if let face = orchestrator.faceDetector.faceLandmarks {
                let rect = LandmarkMath.scale(face.boundingBox, to: size)
                let color = statusColor(orchestrator.enforcement.expressionStatus)

                RoundedRectangle(cornerRadius: 8)
                    .stroke(color, lineWidth: 2)
                    .frame(width: rect.width * 1.2, height: rect.height * 1.2)
                    .position(x: rect.midX, y: rect.midY)

                // Eyes
                if let leftEye = face.leftEye {
                    FaceLandmarkDots(points: leftEye, size: size, color: .cyan)
                }
                if let rightEye = face.rightEye {
                    FaceLandmarkDots(points: rightEye, size: size, color: .cyan)
                }

                // Mouth
                if let outerLips = face.outerLips {
                    FaceLandmarkDots(points: outerLips, size: size, color: .pink)
                }

                // Nose
                if let nose = face.nose {
                    FaceLandmarkDots(points: nose, size: size, color: .yellow)
                }
            }

            // Hand points
            ForEach(Array(orchestrator.handDetector.hands.enumerated()), id: \.offset) { _, hand in
                ForEach(Array(hand.fingertips.enumerated()), id: \.offset) { _, tip in
                    let point = LandmarkMath.scale(tip, to: size)
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
            let points = landmarks.allPoints.mapValues { LandmarkMath.scale($0, to: size) }

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
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
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
                    Image(systemName: "scope")
                        .font(.title2)
                    Text("Calibrate")
                        .font(.caption2)
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
                if orchestrator.isActive {
                    orchestrator.stop()
                } else {
                    orchestrator.start()
                }
            } label: {
                Circle()
                    .fill(orchestrator.isActive ? .red : .green)
                    .frame(width: 64, height: 64)
                    .overlay {
                        Image(systemName: orchestrator.isActive ? "stop.fill" : "play.fill")
                            .font(.title2)
                            .foregroundStyle(.white)
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
