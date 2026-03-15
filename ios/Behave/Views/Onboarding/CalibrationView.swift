import SwiftUI
import AVFoundation

/// Calibration flow:
/// 1. Start camera + detectors → show "Looking for your face..."
/// 2. Face detected → show "Found you! Sit straight and tap Start"
/// 3. User taps Start → 3-2-1 countdown
/// 4. Auto-capture 5 snapshots
/// 5. "Locked in"
struct CalibrationView: View {
    @ObservedObject var orchestrator: SessionOrchestrator
    @Environment(\.dismiss) private var dismiss
    @State private var phase: Phase = .detecting
    @State private var countdown: Int = 3
    @State private var timer: Timer?

    enum Phase {
        case detecting     // waiting to find face
        case faceFound     // face detected — waiting for user to tap Start
        case countdown     // 3-2-1
        case capturing     // auto-capturing
        case done
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // Camera preview
                CameraPreviewView(session: orchestrator.camera.session)
                    .ignoresSafeArea()

                Color.black.opacity(0.3).ignoresSafeArea()

                // Face tracking overlay — follows the face in real-time
                if phase == .detecting || phase == .faceFound {
                    FaceTrackingOverlay(orchestrator: orchestrator)
                        .ignoresSafeArea()
                }

                VStack(spacing: 24) {
                    switch phase {
                    case .detecting:
                        detectingView
                    case .faceFound:
                        faceFoundView
                    case .countdown:
                        countdownView
                    case .capturing:
                        capturingView
                    case .done:
                        doneView
                    }
                }
                .padding()
            }
            .navigationTitle("Calibration")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        cleanup()
                        dismiss()
                    }
                }
            }
            .onAppear {
                // Camera + detectors already running from SessionView.
                // Only start if not already running.
                if !orchestrator.camera.isRunning {
                    orchestrator.startPreview()
                }
                startDetectionPolling()
            }
            .onDisappear {
                cleanup()
            }
        }
    }

    // MARK: - Phase 1: Detecting face

    private var detectingView: some View {
        VStack(spacing: 16) {
            // Top — scanning indicator
            HStack {
                ProgressView()
                    .tint(.white)
                Text("Scanning...")
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial, in: Capsule())
            .padding(.top, 60)

            Spacer()

            // Bottom — instruction
            Text("Position your face in the camera")
                .font(.headline)
                .foregroundStyle(.white)
                .padding(.bottom, 40)
        }
    }

    private func startDetectionPolling() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { _ in
            if orchestrator.faceDetector.faceLandmarks != nil {
                timer?.invalidate()
                timer = nil
                phase = .faceFound
            }
        }
    }

    // MARK: - Phase 2: Face found — user decides when to start

    private var faceFoundView: some View {
        VStack(spacing: 16) {
            // Top — found indicator
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Text("Face detected")
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial, in: Capsule())
            .padding(.top, 60)

            Spacer()

            // Bottom — instruction + button
            VStack(spacing: 12) {
                Text("Sit up straight, then tap Start")
                    .font(.headline)
                    .foregroundStyle(.white)

                Button {
                    orchestrator.startCalibration()
                    startCountdown()
                } label: {
                    Text("Start calibration")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.green)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
            }
            .padding(.bottom, 20)
        }
    }

    // MARK: - Phase 3: Countdown

    private var countdownView: some View {
        VStack(spacing: 20) {
            Spacer()

            Text("\(countdown)")
                .font(.system(size: 96, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            Text("Hold good posture!")
                .font(.title3)
                .foregroundStyle(.white.opacity(0.8))

            Spacer()
        }
    }

    private func startCountdown() {
        phase = .countdown
        countdown = 3

        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if countdown > 1 {
                countdown -= 1
            } else {
                timer?.invalidate()
                timer = nil
                startAutoCapture()
            }
        }
    }

    // MARK: - Phase 4: Capturing

    private var capturingView: some View {
        VStack(spacing: 20) {
            Spacer()

            let progress = Double(orchestrator.calibrationSnapshots.count) / Double(orchestrator.calibrationTarget)

            ZStack {
                Circle()
                    .stroke(.white.opacity(0.3), lineWidth: 4)
                    .frame(width: 120, height: 120)

                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(.green, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .frame(width: 120, height: 120)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.3), value: progress)

                VStack(spacing: 4) {
                    Text("\(orchestrator.calibrationSnapshots.count)")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text("of \(orchestrator.calibrationTarget)")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))
                }
            }

            Text("Capturing...")
                .font(.title3)
                .foregroundStyle(.white)

            Spacer()
        }
    }

    private func startAutoCapture() {
        phase = .capturing

        timer = Timer.scheduledTimer(withTimeInterval: 0.4, repeats: true) { _ in
            orchestrator.captureCalibrationSnapshot()
            if orchestrator.isCalibrated {
                timer?.invalidate()
                timer = nil
                phase = .done
            }
        }
    }

    // MARK: - Phase 5: Done

    private var doneView: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 80))
                .foregroundStyle(.green)

            Text("Locked in")
                .font(.title.bold())
                .foregroundStyle(.white)

            Text("Your baseline posture is saved. Behave will alert you when you deviate.")
                .foregroundStyle(.white.opacity(0.8))
                .multilineTextAlignment(.center)

            Spacer()

            Button {
                dismiss()
            } label: {
                Text("Start monitoring")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.green)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
        }
    }

    // MARK: - Cleanup

    private func cleanup() {
        timer?.invalidate()
        timer = nil
    }
}

// MARK: - Face Tracking Overlay

/// Draws face tracking: bounding box + eyes + mouth landmarks.
/// Proves to the user that face detection is working.
struct FaceTrackingOverlay: View {
    @ObservedObject var orchestrator: SessionOrchestrator

    var body: some View {
        GeometryReader { geo in
            let size = geo.size

            if let face = orchestrator.faceDetector.faceLandmarks {
                let rect = LandmarkMath.scale(face.boundingBox, to: size)

                // Face bounding box
                RoundedRectangle(cornerRadius: 12)
                    .stroke(.green, lineWidth: 2)
                    .frame(width: rect.width * 1.3, height: rect.height * 1.3)
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

                // Eyebrows
                if let leftBrow = face.leftEyebrow {
                    FaceLandmarkDots(points: leftBrow, size: size, color: .green.opacity(0.6))
                }
                if let rightBrow = face.rightEyebrow {
                    FaceLandmarkDots(points: rightBrow, size: size, color: .green.opacity(0.6))
                }
            }
        }
    }
}

/// Draws dots for a set of face landmark points.
struct FaceLandmarkDots: View {
    let points: [CGPoint]
    let size: CGSize
    let color: Color

    var body: some View {
        Canvas { context, _ in
            for point in points {
                let scaled = LandmarkMath.scale(point, to: size)
                let rect = CGRect(x: scaled.x - 2, y: scaled.y - 2, width: 4, height: 4)
                context.fill(Path(ellipseIn: rect), with: .color(color))
            }
        }
    }
}
