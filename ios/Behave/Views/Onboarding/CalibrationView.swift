import SwiftUI

/// Calibration overlay — renders on top of SessionView's camera feed.
/// No sheet, no cover, no second preview layer. Instant.
struct CalibrationOverlay: View {
    @ObservedObject var orchestrator: SessionOrchestrator
    var onDone: () -> Void

    @State private var phase: Phase = .detecting
    @State private var countdown: Int = 3
    @State private var timer: Timer?
    @State private var taughtLeftShoulder: CGPoint?
    @State private var taughtRightShoulder: CGPoint?
    @State private var tappingShoulder: ShoulderSide = .left

    enum Phase {
        case detecting
        case faceFound
        case shoulderTap    // user taps shoulder positions
        case countdown
        case capturing
        case done
    }

    enum ShoulderSide { case left, right }

    var body: some View {
        ZStack {
            // Semi-transparent background
            Color.black.opacity(0.3).ignoresSafeArea()

            // Face tracking + inferred skeleton (visible in all phases except done)
            if phase != .done {
                GeometryReader { geo in
                    let size = geo.size
                    let imgAspect = orchestrator.camera.imageAspectRatio

                    FaceTrackingOverlay(orchestrator: orchestrator)

                    if let face = orchestrator.faceDetector.faceLandmarks {
                        InferredSkeletonView(
                            face: face,
                            screenSize: size,
                            imageAspect: imgAspect,
                            status: orchestrator.isCalibrated ? orchestrator.enforcement.postureStatus : .ok,
                            taughtLeftShoulder: taughtLeftShoulder,
                            taughtRightShoulder: taughtRightShoulder
                        )
                    }
                }
                .ignoresSafeArea()
            }

            VStack(spacing: 24) {
                // Cancel button
                HStack {
                    Button {
                        cleanup()
                        onDone()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.top, 16)

                switch phase {
                case .detecting:
                    detectingView
                case .faceFound:
                    faceFoundView
                case .shoulderTap:
                    shoulderTapView
                case .countdown:
                    countdownView
                case .capturing:
                    capturingView
                case .done:
                    doneView
                }
            }
        }
        .onAppear {
            startDetectionPolling()
        }
        .onDisappear {
            cleanup()
        }
    }

    // MARK: - Detecting

    private var detectingView: some View {
        VStack(spacing: 16) {
            HStack {
                ProgressView().tint(.white)
                Text("Scanning...").font(.subheadline.bold()).foregroundStyle(.white)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial, in: Capsule())

            Spacer()

            Text("Position your face in the camera")
                .font(.headline)
                .foregroundStyle(.white)
                .padding(.bottom, 40)
        }
    }

    private func startDetectionPolling() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { _ in
            if orchestrator.faceDetector.faceLandmarks != nil {
                timer?.invalidate()
                timer = nil
                phase = .faceFound
            }
        }
    }

    // MARK: - Face Found

    private var faceFoundView: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                Text("Face detected").font(.subheadline.bold()).foregroundStyle(.white)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial, in: Capsule())

            Spacer()

            VStack(spacing: 12) {
                Text("Sit up straight, then tap Start")
                    .font(.headline)
                    .foregroundStyle(.white)

                Button {
                    tappingShoulder = .left
                    phase = .shoulderTap
                } label: {
                    Text("Set up shoulders")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.green)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .padding(.horizontal, 32)
            }
            .padding(.bottom, 40)
        }
    }

    // MARK: - Shoulder Tap

    private var shoulderTapView: some View {
        GeometryReader { geo in
            let size = geo.size

            VStack(spacing: 16) {
                HStack {
                    Image(systemName: "hand.tap.fill").foregroundStyle(.cyan)
                    Text(tappingShoulder == .left ? "Tap your LEFT shoulder" : "Tap your RIGHT shoulder")
                        .font(.subheadline.bold()).foregroundStyle(.white)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial, in: Capsule())
                .padding(.top, 60)

                Spacer()

                Text("Tap on the ball of your shoulder joint")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))

                Button("Skip") {
                    orchestrator.startCalibration()
                    startCountdown()
                }
                .font(.caption)
                .foregroundStyle(.white.opacity(0.4))
                .padding(.bottom, 40)
            }

            // Tap indicator dots (show where user tapped)
            if let ls = taughtLeftShoulder {
                let p = LandmarkMath.visionToScreen(ls, screenSize: size, imageAspect: orchestrator.camera.imageAspectRatio)
                Circle().fill(.cyan).frame(width: 20, height: 20).position(p)
                Text("L").font(.caption2.bold()).foregroundStyle(.white).position(p)
            }
            if let rs = taughtRightShoulder {
                let p = LandmarkMath.visionToScreen(rs, screenSize: size, imageAspect: orchestrator.camera.imageAspectRatio)
                Circle().fill(.cyan).frame(width: 20, height: 20).position(p)
                Text("R").font(.caption2.bold()).foregroundStyle(.white).position(p)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { location in
            handleShoulderTap(location)
        }
    }

    private func handleShoulderTap(_ screenPoint: CGPoint) {
        // Convert screen tap to Vision normalized coordinates (reverse of visionToScreen)
        let size = UIScreen.main.bounds.size
        let imgAspect = orchestrator.camera.imageAspectRatio
        let screenAspect = size.width / size.height

        let normX: CGFloat
        let normY: CGFloat

        if imgAspect > screenAspect {
            let r = imgAspect / screenAspect
            normX = ((screenPoint.x / size.width) - 0.5) / r + 0.5
            normY = screenPoint.y / size.height
        } else {
            let r = screenAspect / imgAspect
            normX = screenPoint.x / size.width
            normY = ((screenPoint.y / size.height) - 0.5) / r + 0.5
        }

        let visionPoint = CGPoint(x: normX, y: normY)

        if tappingShoulder == .left {
            taughtLeftShoulder = visionPoint
            tappingShoulder = .right
        } else {
            taughtRightShoulder = visionPoint
            // Both shoulders set — proceed to calibration
            orchestrator.taughtLeftShoulder = taughtLeftShoulder
            orchestrator.taughtRightShoulder = taughtRightShoulder
            orchestrator.startCalibration()
            startCountdown()
        }
    }

    // MARK: - Countdown

    private var countdownView: some View {
        VStack {
            Spacer()
            Text("\(countdown)")
                .font(.system(size: 96, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Text("Hold good posture!")
                .font(.title3).foregroundStyle(.white.opacity(0.8))
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

    // MARK: - Capturing

    private var capturingView: some View {
        VStack {
            Spacer()
            let progress = Double(orchestrator.calibrationSnapshots.count) / Double(orchestrator.calibrationTarget)
            ZStack {
                Circle().stroke(.white.opacity(0.3), lineWidth: 4).frame(width: 120, height: 120)
                Circle().trim(from: 0, to: progress)
                    .stroke(.green, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .frame(width: 120, height: 120)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.3), value: progress)
                VStack(spacing: 4) {
                    Text("\(orchestrator.calibrationSnapshots.count)")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text("of \(orchestrator.calibrationTarget)")
                        .font(.caption).foregroundStyle(.white.opacity(0.7))
                }
            }
            Text("Capturing...").font(.title3).foregroundStyle(.white)
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

    // MARK: - Done

    private var doneView: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 80)).foregroundStyle(.green)
            Text("Locked in").font(.title.bold()).foregroundStyle(.white)
            Text("Your baseline posture is saved.")
                .foregroundStyle(.white.opacity(0.8))
            Spacer()
            Button {
                onDone()
            } label: {
                Text("Start monitoring")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.green)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 40)
        }
    }

    private func cleanup() {
        timer?.invalidate()
        timer = nil
    }
}

// MARK: - Face Tracking Overlay

struct FaceTrackingOverlay: View {
    @ObservedObject var orchestrator: SessionOrchestrator

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            let imgAspect = orchestrator.camera.imageAspectRatio

            if let face = orchestrator.faceDetector.faceLandmarks {
                let rect = LandmarkMath.visionToScreen(face.boundingBox, screenSize: size, imageAspect: imgAspect)

                RoundedRectangle(cornerRadius: 12)
                    .stroke(.green, lineWidth: 2)
                    .frame(width: rect.width * 1.3, height: rect.height * 1.3)
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
                if let leftBrow = face.leftEyebrow {
                    FaceLandmarkDots(points: leftBrow, size: size, imageAspect: imgAspect, color: .green.opacity(0.6))
                }
                if let rightBrow = face.rightEyebrow {
                    FaceLandmarkDots(points: rightBrow, size: size, imageAspect: imgAspect, color: .green.opacity(0.6))
                }
            }
        }
    }
}

struct FaceLandmarkDots: View {
    let points: [CGPoint]
    let size: CGSize
    let imageAspect: CGFloat
    let color: Color

    var body: some View {
        Canvas { context, _ in
            for point in points {
                let scaled = LandmarkMath.visionToScreen(point, screenSize: size, imageAspect: imageAspect)
                let rect = CGRect(x: scaled.x - 3, y: scaled.y - 3, width: 6, height: 6)
                context.fill(Path(ellipseIn: rect), with: .color(color))
            }
        }
    }
}
