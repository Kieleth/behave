import SwiftUI
import AVFoundation

/// Calibration flow:
/// 1. Start camera + detectors immediately
/// 2. Wait until face is detected → "Got you!"
/// 3. Auto-countdown 3-2-1
/// 4. Auto-capture 5 snapshots
/// 5. Done → "Locked in"
struct CalibrationView: View {
    @ObservedObject var orchestrator: SessionOrchestrator
    @Environment(\.dismiss) private var dismiss
    @State private var phase: Phase = .detecting
    @State private var countdown: Int = 3
    @State private var timer: Timer?
    @State private var detectionCheckTimer: Timer?

    enum Phase {
        case detecting   // waiting for face
        case countdown   // 3-2-1
        case capturing   // auto-capturing snapshots
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
                // Start detectors immediately
                orchestrator.startPreview()
                orchestrator.startCalibration()
                startDetectionCheck()
            }
            .onDisappear {
                cleanup()
            }
        }
    }

    // MARK: - Phase 1: Detecting

    private var detectingView: some View {
        VStack(spacing: 20) {
            Spacer()

            ProgressView()
                .scaleEffect(1.5)
                .tint(.white)

            Text("Looking for you...")
                .font(.title2.bold())
                .foregroundStyle(.white)

            Text("Make sure your face is visible in the camera")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.7))
                .multilineTextAlignment(.center)

            // Live detection status
            VStack(alignment: .leading, spacing: 8) {
                detectionRow("Face", detected: orchestrator.faceDetector.faceLandmarks != nil)
                detectionRow("Body", detected: orchestrator.poseDetector.bodyLandmarks != nil)
            }
            .padding()
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))

            Spacer()
        }
    }

    private func detectionRow(_ label: String, detected: Bool) -> some View {
        HStack(spacing: 8) {
            Image(systemName: detected ? "checkmark.circle.fill" : "circle.dotted")
                .foregroundStyle(detected ? .green : .gray)
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.white)
            Spacer()
            Text(detected ? "Detected" : "Searching...")
                .font(.caption)
                .foregroundStyle(detected ? .green : .gray)
        }
    }

    private func startDetectionCheck() {
        // Poll every 0.3s to see if we can detect the user
        detectionCheckTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { _ in
            if orchestrator.isUserDetected {
                detectionCheckTimer?.invalidate()
                detectionCheckTimer = nil
                startCountdown()
            }
        }
    }

    // MARK: - Phase 2: Countdown

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
                startAutoCapture()
            }
        }
    }

    // MARK: - Phase 3: Capturing

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
                phase = .done
            }
        }
    }

    // MARK: - Phase 4: Done

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
        detectionCheckTimer?.invalidate()
        detectionCheckTimer = nil
    }
}
