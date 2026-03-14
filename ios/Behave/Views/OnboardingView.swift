import SwiftUI
import AVFoundation
import Speech

/// First-launch onboarding: welcome → BIPA consent → permissions → calibration.
/// Must complete before the main app is accessible.
struct OnboardingView: View {
    @ObservedObject var consentManager: ConsentManager
    @State private var step: Step = .welcome

    enum Step {
        case welcome
        case consent
        case permissions
        case ready
    }

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()

            switch step {
            case .welcome:
                welcomeStep
            case .consent:
                consentStep
            case .permissions:
                permissionsStep
            case .ready:
                readyStep
            }
        }
        .animation(.easeInOut, value: step)
    }

    // MARK: - Welcome

    private var welcomeStep: some View {
        VStack(spacing: 32) {
            Spacer()

            Image(systemName: "figure.stand")
                .font(.system(size: 80))
                .foregroundStyle(.blue)

            VStack(spacing: 12) {
                Text("Behave")
                    .font(.largeTitle.bold())
                Text("Your personal behavioral coach")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 16) {
                featureRow("figure.walk", "Posture monitoring", "Real-time feedback on your posture")
                featureRow("hand.raised", "Habit tracking", "Catch nail biting, face touching, hair pulling")
                featureRow("waveform", "Speech analysis", "Track filler words and speaking pace")
                featureRow("lock.shield", "100% on-device", "Your data never leaves your phone")
            }
            .padding(.horizontal, 32)

            Spacer()

            Button {
                step = .consent
            } label: {
                Text("Get started")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.blue)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 32)
        }
    }

    // MARK: - BIPA Consent

    private var consentStep: some View {
        VStack(spacing: 20) {
            HStack {
                Button("Back") { step = .welcome }
                    .foregroundStyle(.blue)
                Spacer()
            }
            .padding(.horizontal)

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Label("Privacy disclosure", systemImage: "doc.text.magnifyingglass")
                        .font(.title2.bold())
                        .padding(.bottom, 4)

                    Text(ConsentManager.disclosureText)
                        .font(.subheadline)
                        .lineSpacing(4)
                }
                .padding(.horizontal, 24)
            }

            VStack(spacing: 12) {
                Button {
                    consentManager.grantConsent()
                    step = .permissions
                } label: {
                    Text("I understand & agree")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.blue)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }

                Button("I do not agree") {
                    // Stay on consent screen — can't proceed without consent
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 32)
        }
    }

    // MARK: - Permissions

    private var permissionsStep: some View {
        VStack(spacing: 32) {
            Spacer()

            Image(systemName: "camera.badge.ellipsis")
                .font(.system(size: 60))
                .foregroundStyle(.blue)

            VStack(spacing: 8) {
                Text("Camera & microphone")
                    .font(.title2.bold())
                Text("Behave needs access to monitor your posture and speech.\nAll processing happens on this device.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 32)

            VStack(spacing: 16) {
                permissionRow("camera.fill", "Camera", "Posture, expressions, habits")
                permissionRow("mic.fill", "Microphone", "Speech patterns (optional)")
            }
            .padding(.horizontal, 32)

            Spacer()

            Button {
                requestPermissions()
            } label: {
                Text("Allow access")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.blue)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding(.horizontal, 32)

            Button("Skip for now") {
                step = .ready
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .padding(.bottom, 32)
        }
    }

    // MARK: - Ready

    private var readyStep: some View {
        VStack(spacing: 32) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 80))
                .foregroundStyle(.green)

            VStack(spacing: 8) {
                Text("You're all set")
                    .font(.title.bold())
                Text("Place your phone next to your laptop during work sessions. Behave will monitor your behavior and help you improve.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 32)

            Spacer()

            Button {
                // Onboarding complete — ContentView will detect consent and show main app
            } label: {
                Text("Start using Behave")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.blue)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 32)
        }
    }

    // MARK: - Helpers

    private func featureRow(_ icon: String, _ title: String, _ subtitle: String) -> some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.blue)
                .frame(width: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.bold())
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private func permissionRow(_ icon: String, _ title: String, _ subtitle: String) -> some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.blue)
                .frame(width: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.bold())
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private func requestPermissions() {
        AVCaptureDevice.requestAccess(for: .video) { _ in
            AVCaptureDevice.requestAccess(for: .audio) { _ in
                SFSpeechRecognizer.requestAuthorization { _ in
                    DispatchQueue.main.async {
                        step = .ready
                    }
                }
            }
        }
    }
}
