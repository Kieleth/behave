import SwiftUI

/// Calibration flow — modern version of the original auto-adjust protocol.
/// User sits straight, app captures N snapshots of "good posture" to learn baseline.
struct CalibrationView: View {
    @ObservedObject var orchestrator: SessionOrchestrator
    @Environment(\.dismiss) private var dismiss
    @State private var phase: CalibrationPhase = .instructions

    enum CalibrationPhase {
        case instructions
        case capturing
        case done
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                switch phase {
                case .instructions:
                    instructionsView
                case .capturing:
                    capturingView
                case .done:
                    doneView
                }
            }
            .padding()
            .navigationTitle("Calibration")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private var instructionsView: some View {
        VStack(spacing: 20) {
            Image(systemName: "figure.stand")
                .font(.system(size: 64))
                .foregroundStyle(.blue)

            Text("Sit up straight")
                .font(.title2.bold())

            Text("Position yourself comfortably with good posture. Behave will take \(orchestrator.calibrationTarget) snapshots to learn your baseline.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Spacer()

            Button {
                orchestrator.startCalibration()
                orchestrator.start()
                phase = .capturing
            } label: {
                Text("Start Calibration")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
    }

    private var capturingView: some View {
        VStack(spacing: 20) {
            let progress = Double(orchestrator.calibrationSnapshots.count) / Double(orchestrator.calibrationTarget)

            ProgressView(value: progress)
                .progressViewStyle(.linear)
                .tint(.blue)

            Text("\(orchestrator.calibrationSnapshots.count) of \(orchestrator.calibrationTarget)")
                .font(.system(.title, design: .monospaced))

            Text("Hold still with good posture...")
                .foregroundStyle(.secondary)

            Spacer()

            Button {
                orchestrator.captureCalibrationSnapshot()
                if orchestrator.isCalibrated {
                    phase = .done
                    orchestrator.stop()
                }
            } label: {
                Text("Capture")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
    }

    private var doneView: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.green)

            Text("Calibration Complete")
                .font(.title2.bold())

            Text("Behave has learned your baseline posture. You're ready to start a session.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Spacer()

            Button {
                dismiss()
            } label: {
                Text("Done")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
    }
}
