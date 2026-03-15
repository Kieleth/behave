import Vision
import CoreMedia
import Combine

/// Detects hand pose (21 landmarks per hand) using Vision framework.
final class HandDetector: ObservableObject {
    @Published var hands: [HandLandmarks] = []

    private let request: VNDetectHumanHandPoseRequest = {
        let req = VNDetectHumanHandPoseRequest()
        req.maximumHandCount = 2
        return req
    }()

    func detect(in sampleBuffer: CMSampleBuffer, orientation: CGImagePropertyOrientation = .right) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: orientation)
        try? handler.perform([request])

        let results = (request.results ?? []).map { HandLandmarks(from: $0) }
        DispatchQueue.main.async { self.hands = results }
    }
}

/// Extracted hand landmark data.
struct HandLandmarks {
    let wrist: CGPoint?
    let thumbTip: CGPoint?
    let indexTip: CGPoint?
    let middleTip: CGPoint?
    let ringTip: CGPoint?
    let littleTip: CGPoint?

    /// All fingertips for proximity checks
    var fingertips: [CGPoint] {
        [thumbTip, indexTip, middleTip, ringTip, littleTip].compactMap { $0 }
    }

    let allPoints: [VNHumanHandPoseObservation.JointName: CGPoint]

    init(from observation: VNHumanHandPoseObservation) {
        func point(for joint: VNHumanHandPoseObservation.JointName) -> CGPoint? {
            guard let p = try? observation.recognizedPoint(joint),
                  p.confidence > 0.3 else { return nil }
            // Flip X for front-camera mirror, Y is already top-down with .right orientation
            return CGPoint(x: 1 - p.location.x, y: p.location.y)
        }

        self.wrist = point(for: .wrist)
        self.thumbTip = point(for: .thumbTip)
        self.indexTip = point(for: .indexTip)
        self.middleTip = point(for: .middleTip)
        self.ringTip = point(for: .ringTip)
        self.littleTip = point(for: .littleTip)

        var all: [VNHumanHandPoseObservation.JointName: CGPoint] = [:]
        let joints: [VNHumanHandPoseObservation.JointName] = [
            .wrist, .thumbCMC, .thumbMP, .thumbIP, .thumbTip,
            .indexMCP, .indexPIP, .indexDIP, .indexTip,
            .middleMCP, .middlePIP, .middleDIP, .middleTip,
            .ringMCP, .ringPIP, .ringDIP, .ringTip,
            .littleMCP, .littlePIP, .littleDIP, .littleTip,
        ]
        for joint in joints {
            if let p = point(for: joint) {
                all[joint] = p
            }
        }
        self.allPoints = all
    }
}
