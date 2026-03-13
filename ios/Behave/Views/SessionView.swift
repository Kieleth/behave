import SwiftUI
import AVFoundation

/// Main session screen: camera preview with detection overlays.
struct SessionView: View {
    @StateObject private var orchestrator = SessionOrchestrator()
    @State private var showCalibration = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                if orchestrator.camera.permissionGranted {
                    // Camera preview
                    CameraPreviewView(session: orchestrator.camera.session)
                        .ignoresSafeArea()

                    // Detection overlays
                    DetectionOverlay(orchestrator: orchestrator)

                    // Status bar at top
                    VStack {
                        StatusBar(orchestrator: orchestrator)
                        Spacer()
                        ControlBar(orchestrator: orchestrator, showCalibration: $showCalibration)
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
        }
    }
}

// MARK: - Camera Preview (UIKit bridge)

struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)
        context.coordinator.previewLayer = previewLayer
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.previewLayer?.frame = uiView.bounds
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    class Coordinator {
        var previewLayer: AVCaptureVideoPreviewLayer?
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
