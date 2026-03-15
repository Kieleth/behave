import SwiftUI
import AVFoundation

/// Calibration flow — user sits with good posture, app auto-captures snapshots.
/// Shows camera preview so user can see their positioning.
struct CalibrationView: View {
    @ObservedObject var orchestrator: SessionOrchestrator
    @Environment(\.dismiss) private var dismiss
    @State private var phase: CalibrationPhase = .instructions
    @State private var countdown: Int = 3
    @State private var timer: Timer?

    enum CalibrationPhase {
        case instructions
        case countdown
        case capturing
        case done
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // Camera preview background
                if phase != .instructions {
                    CameraPreviewView(session: orchestrator.camera.session)
                        .ignoresSafeArea()

                    // Dim overlay so text is readable
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()
                }

                VStack(spacing: 24) {
                    switch phase {
                    case .instructions:
                        instructionsView
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
                        timer?.invalidate()
                        dismiss()
                    }
                }
            }
            .onDisappear {
                timer?.invalidate()
            }
        }
    }

    // MARK: - Instructions

    private var instructionsView: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "figure.stand")
                .font(.system(size: 64))
                .foregroundStyle(.blue)

            Text("Sit up straight")
                .font(.title2.bold())

            VStack(alignment: .leading, spacing: 12) {
                instructionRow("1", "Sit comfortably with good posture")
                instructionRow("2", "Face the camera, shoulders visible")
                instructionRow("3", "Hold still for 5 seconds")
            }
            .padding()

            Spacer()

            Button {
                startCountdown()
            } label: {
                Text("I'm ready")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.blue)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
        }
    }

    private func instructionRow(_ number: String, _ text: String) -> some View {
        HStack(spacing: 12) {
            Text(number)
                .font(.headline)
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(.blue, in: Circle())
            Text(text)
                .font(.subheadline)
        }
    }

    // MARK: - Countdown

    private var countdownView: some View {
        VStack(spacing: 20) {
            Spacer()

            Text("\(countdown)")
                .font(.system(size: 96, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            Text("Get into position...")
                .font(.title3)
                .foregroundStyle(.white.opacity(0.8))

            Spacer()
        }
    }

    private func startCountdown() {
        // Start camera if not already running
        orchestrator.camera.start()
        orchestrator.startCalibration()
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

    // MARK: - Capturing

    private var capturingView: some View {
        VStack(spacing: 20) {
            Spacer()

            let progress = Double(orchestrator.calibrationSnapshots.count) / Double(orchestrator.calibrationTarget)

            // Pulsing ring
            ZStack {
                Circle()
                    .stroke(.white.opacity(0.3), lineWidth: 4)
                    .frame(width: 120, height: 120)

                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(.green, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .frame(width: 120, height: 120)
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 4) {
                    Text("\(orchestrator.calibrationSnapshots.count)")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text("of \(orchestrator.calibrationTarget)")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))
                }
            }

            Text("Hold still...")
                .font(.title3)
                .foregroundStyle(.white)

            Text("Capturing your baseline posture")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.6))

            Spacer()
        }
    }

    private func startAutoCapture() {
        phase = .capturing

        // Auto-capture every 0.5 seconds
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            orchestrator.captureCalibrationSnapshot()
            if orchestrator.isCalibrated {
                timer?.invalidate()
                phase = .done
            }
        }
    }

    // MARK: - Done

    private var doneView: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 80))
                .foregroundStyle(.green)

            Text("Locked in")
                .font(.title.bold())
                .foregroundStyle(.white)

            Text("Your baseline posture is saved. Behave will alert you when you deviate from it.")
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
}
