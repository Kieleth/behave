import SwiftUI
import SwiftData
import AVFoundation
import Vision

/// Main session screen: camera preview with detection overlays.
struct SessionView: View {
    @StateObject private var orchestrator = SessionOrchestrator()
    @Environment(\.modelContext) private var modelContext
    @State private var showCalibration = false
    @State private var showDebug = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                if orchestrator.camera.permissionGranted {
                    // Camera preview (always visible for feedback)
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
                    } else {
                        // Idle state — prompt to start
                        VStack(spacing: 16) {
                            Spacer()
                            Image(systemName: "figure.stand")
                                .font(.system(size: 48))
                                .foregroundStyle(.white.opacity(0.7))
                            Text("Place your phone next to your laptop")
                                .font(.headline)
                                .foregroundStyle(.white)
                            Text("Tap the button below to start monitoring")
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.6))
                            Spacer()
                        }
                    }

                    // Status bar at top, controls at bottom
                    VStack {
                        if orchestrator.isActive {
                            HStack {
                                StatusBar(orchestrator: orchestrator)
                                Spacer()
                                PomodoroOverlay(pomodoro: orchestrator.pomodoro)
                            }
                        }

                        // Debug overlay (top-left, below status bar)
                        if showDebug {
                            HStack {
                                DebugOverlay(orchestrator: orchestrator)
                                Spacer()
                            }
                        }

                        Spacer()

                        HStack {
                            ControlBar(orchestrator: orchestrator, showCalibration: $showCalibration)
                        }

                        // Debug toggle
                        Button {
                            showDebug.toggle()
                        } label: {
                            Text(showDebug ? "Hide debug" : "Debug")
                                .font(.caption2)
                                .foregroundStyle(.white.opacity(0.4))
                        }
                        .padding(.top, 4)
                    }
                    .padding()
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
            .sheet(isPresented: $showCalibration) {
                CalibrationView(orchestrator: orchestrator)
            }
            .task {
                orchestrator.modelContext = modelContext
                orchestrator.loadSettings()
                // Start camera preview immediately for visual feedback
                orchestrator.camera.start()
            }
            .onChange(of: orchestrator.isActive) { _, active in
                // Keep screen on during active sessions
                UIApplication.shared.isIdleTimerDisabled = active
            }
            .onDisappear {
                UIApplication.shared.isIdleTimerDisabled = false
            }
        }
    }
}

// MARK: - Debug Overlay

struct DebugOverlay: View {
    @ObservedObject var orchestrator: SessionOrchestrator

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("DEBUG")
                .font(.caption.bold().monospaced())
                .foregroundStyle(.yellow)

            Group {
                if let body = orchestrator.poseDetector.bodyLandmarks {
                    let pts = body.allPoints.count
                    Text("Pose: \(pts) joints")
                    if let nose = body.nose {
                        Text("  nose: (\(f(nose.x)), \(f(nose.y)))")
                    }
                    if let ls = body.leftShoulder, let rs = body.rightShoulder {
                        Text("  shoulders: L(\(f(ls.x)),\(f(ls.y))) R(\(f(rs.x)),\(f(rs.y)))")
                    }
                } else {
                    Text("Pose: none")
                }

                if let face = orchestrator.faceDetector.faceLandmarks {
                    let b = face.boundingBox
                    Text("Face: (\(f(b.minX)),\(f(b.minY))) \(f(b.width))x\(f(b.height))")
                } else {
                    Text("Face: none")
                }

                Text("Hands: \(orchestrator.handDetector.hands.count)")

                Text("Calibrated: \(orchestrator.isCalibrated ? "YES" : "NO")")

                let e = orchestrator.enforcement
                Text("Score: P:\(f(e.postureStatus.score)) E:\(f(e.expressionStatus.score)) H:\(f(e.habitStatus.score))")
            }
            .font(.caption2.monospaced())
            .foregroundStyle(.green)
        }
        .padding(8)
        .background(.black.opacity(0.7), in: RoundedRectangle(cornerRadius: 8))
    }

    private func f(_ v: Double) -> String { String(format: "%.2f", v) }
    private func f(_ v: CGFloat) -> String { String(format: "%.2f", v) }
}

// MARK: - Camera Preview (UIKit bridge)

struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewUIView {
        let view = PreviewUIView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: PreviewUIView, context: Context) {
        // Session may change — update it
        uiView.previewLayer.session = session
    }

    /// Custom UIView that keeps the preview layer sized to bounds via layoutSubviews.
    class PreviewUIView: UIView {
        let previewLayer = AVCaptureVideoPreviewLayer()

        override init(frame: CGRect) {
            super.init(frame: frame)
            layer.addSublayer(previewLayer)
        }

        required init?(coder: NSCoder) { fatalError() }

        override func layoutSubviews() {
            super.layoutSubviews()
            previewLayer.frame = bounds
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

            // Face bounding box
            if let face = orchestrator.faceDetector.faceLandmarks {
                let rect = LandmarkMath.scale(face.boundingBox, to: size)
                Rectangle()
                    .stroke(statusColor(orchestrator.enforcement.expressionStatus), lineWidth: 2)
                    .frame(width: rect.width, height: rect.height)
                    .position(x: rect.midX, y: rect.midY)
            }

            // Hand points near face (habit warning)
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

            // Draw joints
            for (_, point) in points {
                let rect = CGRect(x: point.x - 4, y: point.y - 4, width: 8, height: 8)
                context.fill(Path(ellipseIn: rect), with: .color(color))
            }

            // Draw bone connections
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
            // Calibrate button
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

            // Duration
            if orchestrator.isActive {
                Text(formatDuration(orchestrator.sessionDuration))
                    .font(.system(.title3, design: .monospaced))
                    .foregroundStyle(.white)
            }

            Spacer()

            // Start/Stop button
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
