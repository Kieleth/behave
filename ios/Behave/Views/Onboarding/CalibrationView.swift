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

                Color.black.opacity(0.4).ignoresSafeArea()

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
                orchestrator.startPreview()
                startDetectionPolling()
            }
            .onDisappear {
                cleanup()
            }
        }
    }

    // MARK: - Phase 1: Detecting face

    private var detectingView: some View {
        VStack(spacing: 20) {
            Spacer()

            ProgressView()
                .scaleEffect(1.5)
                .tint(.white)
                .padding(.bottom, 8)

            Text("Looking for your face...")
                .font(.title2.bold())
                .foregroundStyle(.white)

            Text("Make sure your face is visible in the camera")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.7))
                .multilineTextAlignment(.center)

            // Live status
            VStack(alignment: .leading, spacing: 8) {
                statusRow("Face", orchestrator.faceDetector.faceLandmarks != nil)
                statusRow("Body", orchestrator.poseDetector.bodyLandmarks != nil)
                statusRow("Frames", orchestrator.processedFrameCount > 0)
            }
            .padding()
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))

            Spacer()
        }
    }

    private func statusRow(_ label: String, _ ok: Bool) -> some View {
        HStack(spacing: 8) {
            Image(systemName: ok ? "checkmark.circle.fill" : "circle.dotted")
                .foregroundStyle(ok ? .green : .gray)
            Text(label)
                .foregroundStyle(.white)
            Spacer()
            Text(ok ? "OK" : "...")
                .font(.caption)
                .foregroundStyle(ok ? .green : .gray)
        }
        .font(.subheadline)
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
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "face.smiling.fill")
                .font(.system(size: 64))
                .foregroundStyle(.green)

            Text("Found you!")
                .font(.title.bold())
                .foregroundStyle(.white)

            Text("Sit up straight with good posture, then tap Start to calibrate.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.7))
                .multilineTextAlignment(.center)

            Spacer()

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
