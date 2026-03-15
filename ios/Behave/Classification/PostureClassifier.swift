import Foundation

/// Classifies posture quality from body pose landmarks.
/// Direct descendant of the original `EnforceFaceLimits.is_face_ok`.
struct PostureClassifier {

    struct Result {
        let isGood: Bool
        let shoulderTilt: Double      // degrees off horizontal
        let headDrop: Double           // how far head has dropped from calibrated position
        let forwardLean: Double        // nose-to-shoulder depth ratio
        let details: String
    }

    struct Calibration {
        var noseY: Double = 0
        var shoulderMidY: Double = 0
        var headToShoulderRatio: Double = 0
        var shoulderAngle: Double = 0
    }

    /// Thresholds (configurable)
    var maxShoulderTilt: Double = 8.0      // degrees
    var maxHeadDrop: Double = 0.08         // normalized
    var maxForwardLean: Double = 0.15      // ratio deviation

    func classify(landmarks: BodyLandmarks, calibration: Calibration) -> Result {
        guard let nose = landmarks.nose,
              let leftShoulder = landmarks.leftShoulder,
              let rightShoulder = landmarks.rightShoulder else {
            return Result(isGood: true, shoulderTilt: 0, headDrop: 0, forwardLean: 0, details: "Insufficient landmarks")
        }

        // Shoulder tilt: angle between shoulder line and horizontal
        let shoulderTilt = LandmarkMath.angleDegrees(
            from: leftShoulder,
            to: rightShoulder
        )

        // Head drop: how far nose Y has moved from calibrated position
        let headDrop = nose.y - calibration.noseY

        // Head-to-shoulder ratio: vertical distance between nose and shoulder midpoint
        let shoulderMidY = (leftShoulder.y + rightShoulder.y) / 2
        let currentRatio = abs(nose.y - shoulderMidY)
        let forwardLean = currentRatio - calibration.headToShoulderRatio

        // Evaluate
        let tiltOk = abs(shoulderTilt) < maxShoulderTilt
        let dropOk = headDrop < maxHeadDrop
        let leanOk = abs(forwardLean) < maxForwardLean
        let isGood = tiltOk && dropOk && leanOk

        var issues: [String] = []
        if !tiltOk { issues.append("shoulders tilted") }
        if !dropOk { issues.append("slouching") }
        if !leanOk { issues.append("leaning forward") }

        let details = isGood ? "Good posture" : issues.joined(separator: ", ")

        return Result(
            isGood: isGood,
            shoulderTilt: shoulderTilt,
            headDrop: headDrop,
            forwardLean: forwardLean,
            details: details
        )
    }

    /// Calibrate from a series of "good posture" snapshots.
    /// Mirrors the original auto-adjust protocol.
    static func calibrate(from snapshots: [BodyLandmarks]) -> Calibration {
        let valid = snapshots.compactMap { lm -> (CGPoint, CGPoint, CGPoint)? in
            guard let n = lm.nose, let ls = lm.leftShoulder, let rs = lm.rightShoulder else { return nil }
            return (n, ls, rs)
        }
        guard !valid.isEmpty else { return Calibration() }

        let count = Double(valid.count)
        let avgNoseY = valid.reduce(0.0) { $0 + $1.0.y } / count
        let avgShoulderMidY = valid.reduce(0.0) { $0 + ($1.1.y + $1.2.y) / CGFloat(2) } / count
        let avgRatio = valid.reduce(0.0) { $0 + abs($1.0.y - ($1.1.y + $1.2.y) / CGFloat(2)) } / count
        let avgAngle = valid.reduce(0.0) { $0 + LandmarkMath.angleDegrees(from: $1.1, to: $1.2) } / count

        return Calibration(
            noseY: avgNoseY,
            shoulderMidY: avgShoulderMidY,
            headToShoulderRatio: avgRatio,
            shoulderAngle: avgAngle
        )
    }
}
