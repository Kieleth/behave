import Vision
import CoreMedia
import Combine

/// Detects human body pose (19 joint points) using Vision framework on Neural Engine.
/// Replaces the original `CascadeClassifier` + `detect_face_in_frame`.
final class PoseDetector: ObservableObject {
    @Published var bodyLandmarks: BodyLandmarks?

    private let request = VNDetectHumanBodyPoseRequest()

    func detect(in sampleBuffer: CMSampleBuffer, orientation: CGImagePropertyOrientation = .right) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: orientation)
        try? handler.perform([request])

        guard let observation = request.results?.first else {
            DispatchQueue.main.async { self.bodyLandmarks = nil }
            return
        }

        let landmarks = BodyLandmarks(from: observation)
        DispatchQueue.main.async { self.bodyLandmarks = landmarks }
    }
}

/// Normalized body landmark positions extracted from Vision observation.
struct BodyLandmarks {
    let nose: CGPoint?
    let neck: CGPoint?
    let leftShoulder: CGPoint?
    let rightShoulder: CGPoint?
    let leftElbow: CGPoint?
    let rightElbow: CGPoint?
    let leftWrist: CGPoint?
    let rightWrist: CGPoint?
    let leftHip: CGPoint?
    let rightHip: CGPoint?
    let leftEar: CGPoint?
    let rightEar: CGPoint?
    let leftEye: CGPoint?
    let rightEye: CGPoint?

    /// All available points for rendering skeleton
    let allPoints: [VNHumanBodyPoseObservation.JointName: CGPoint]

    /// Fallback init from face-estimated positions (when body pose isn't detected).
    init(nose: CGPoint?, leftShoulder: CGPoint?, rightShoulder: CGPoint?) {
        self.nose = nose
        self.neck = nil
        self.leftShoulder = leftShoulder
        self.rightShoulder = rightShoulder
        self.leftElbow = nil
        self.rightElbow = nil
        self.leftWrist = nil
        self.rightWrist = nil
        self.leftHip = nil
        self.rightHip = nil
        self.leftEar = nil
        self.rightEar = nil
        self.leftEye = nil
        self.rightEye = nil
        var all: [VNHumanBodyPoseObservation.JointName: CGPoint] = [:]
        if let n = nose { all[.nose] = n }
        if let ls = leftShoulder { all[.leftShoulder] = ls }
        if let rs = rightShoulder { all[.rightShoulder] = rs }
        self.allPoints = all
    }

    init(from observation: VNHumanBodyPoseObservation) {
        let points = try? observation.recognizedPoints(.all)

        func point(for joint: VNHumanBodyPoseObservation.JointName) -> CGPoint? {
            guard let p = points?[joint], p.confidence > 0.3 else { return nil }
            // Vision coordinates: origin bottom-left, y-up. Convert to top-left.
            return CGPoint(x: p.location.x, y: 1 - p.location.y)
        }

        self.nose = point(for: .nose)
        self.neck = point(for: .neck)
        self.leftShoulder = point(for: .leftShoulder)
        self.rightShoulder = point(for: .rightShoulder)
        self.leftElbow = point(for: .leftElbow)
        self.rightElbow = point(for: .rightElbow)
        self.leftWrist = point(for: .leftWrist)
        self.rightWrist = point(for: .rightWrist)
        self.leftHip = point(for: .leftHip)
        self.rightHip = point(for: .rightHip)
        self.leftEar = point(for: .leftEar)
        self.rightEar = point(for: .rightEar)
        self.leftEye = point(for: .leftEye)
        self.rightEye = point(for: .rightEye)

        var all: [VNHumanBodyPoseObservation.JointName: CGPoint] = [:]
        if let pts = points {
            for (name, recognized) in pts where recognized.confidence > 0.3 {
                all[name] = CGPoint(x: recognized.location.x, y: 1 - recognized.location.y)
            }
        }
        self.allPoints = all
    }
}
