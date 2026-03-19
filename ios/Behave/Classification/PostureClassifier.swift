import Foundation

/// Classifies posture quality from body pose and/or face landmarks.
/// Works with body pose (shoulders + head) or face-only (bounding box size/position).
struct PostureClassifier {

    struct Result {
        let isGood: Bool
        let shoulderTilt: Double       // degrees off horizontal
        let headDropRatio: Double      // 0 = calibrated, positive = slouching
        let shoulderShrug: Double      // how much shoulders raised toward head
        let details: String
        let source: Source             // what data was used

        enum Source { case bodyPose, faceOnly, insufficient }
    }

    struct Calibration {
        var noseY: Double = 0
        var shoulderMidY: Double = 0
        var headToShoulderRatio: Double = 0   // nose-to-shoulderMid / shoulderWidth
        var shoulderAngle: Double = 0
        var shoulderWidth: Double = 0         // distance between shoulders (normalization)
        var faceBBoxHeight: Double = 0        // face bounding box height when calibrated
        var faceBBoxCenterY: Double = 0       // face center Y when calibrated
        var faceBBoxCenterX: Double = 0       // lateral position at calibration
        var calibratedRoll: Double = 0        // eye-line angle at calibration
        var calibratedNoseOffset: Double = 0  // nose X offset at calibration
    }

    /// Thresholds
    var maxShoulderTilt: Double = 10.0     // degrees
    var maxHeadDropRatio: Double = 0.20    // 20% change in head-to-shoulder ratio
    var maxShoulderShrug: Double = 0.15    // shoulder rise relative to shoulder width

    func classify(landmarks: BodyLandmarks, calibration: Calibration) -> Result {
        guard let nose = landmarks.nose,
              let leftShoulder = landmarks.leftShoulder,
              let rightShoulder = landmarks.rightShoulder else {
            return Result(isGood: true, shoulderTilt: 0, headDropRatio: 0, shoulderShrug: 0,
                         details: "Insufficient landmarks", source: .insufficient)
        }

        // Shoulder tilt
        let shoulderTilt = LandmarkMath.angleDegrees(from: leftShoulder, to: rightShoulder)

        // Shoulder width (used as normalization factor — scale invariant)
        let shoulderWidth = LandmarkMath.distance(leftShoulder, rightShoulder)
        guard shoulderWidth > 0.01 else {
            return Result(isGood: true, shoulderTilt: 0, headDropRatio: 0, shoulderShrug: 0,
                         details: "Shoulders too narrow", source: .insufficient)
        }

        // Head-to-shoulder ratio: vertical distance / shoulder width
        // This is scale-invariant: works regardless of distance from camera
        let shoulderMidY = (leftShoulder.y + rightShoulder.y) / 2
        let headToShoulder = abs(Double(nose.y) - Double(shoulderMidY)) / shoulderWidth
        let headDropRatio: Double
        if calibration.headToShoulderRatio > 0 {
            // How much the ratio has decreased (head moved toward shoulders = slouching)
            headDropRatio = (calibration.headToShoulderRatio - headToShoulder) / calibration.headToShoulderRatio
        } else {
            headDropRatio = 0
        }

        // Shoulder shrug: shoulders rising toward head
        let shoulderShrug: Double
        if calibration.shoulderWidth > 0 {
            let calibratedGap = abs(calibration.noseY - calibration.shoulderMidY)
            let currentGap = abs(Double(nose.y) - Double(shoulderMidY))
            shoulderShrug = calibratedGap > 0 ? (calibratedGap - currentGap) / calibratedGap : 0
        } else {
            shoulderShrug = 0
        }

        // Evaluate
        let tiltOk = abs(shoulderTilt - calibration.shoulderAngle) < maxShoulderTilt
        let dropOk = headDropRatio < maxHeadDropRatio
        let shrugOk = shoulderShrug < maxShoulderShrug
        let isGood = tiltOk && dropOk && shrugOk

        var issues: [String] = []
        if !tiltOk { issues.append("shoulders tilted") }
        if !dropOk { issues.append("slouching") }
        if !shrugOk { issues.append("shoulders raised") }

        return Result(
            isGood: isGood,
            shoulderTilt: shoulderTilt - calibration.shoulderAngle,
            headDropRatio: headDropRatio,
            shoulderShrug: shoulderShrug,
            details: isGood ? "Good posture" : issues.joined(separator: ", "),
            source: .bodyPose
        )
    }

    /// Face-only classification: uses face bounding box + landmark geometry
    /// when body pose isn't available. Infers posture from face signals.
    func classifyFromFace(_ face: FaceLandmarks, calibration: Calibration) -> Result {
        guard calibration.faceBBoxHeight > 0 else {
            return Result(isGood: true, shoulderTilt: 0, headDropRatio: 0, shoulderShrug: 0,
                         details: "Not calibrated for face", source: .insufficient)
        }

        let box = face.boundingBox
        var issues: [String] = []

        // 1. Forward lean: face gets larger (closer to camera)
        let sizeChange = (Double(box.height) - calibration.faceBBoxHeight) / calibration.faceBBoxHeight
        let leanOk = sizeChange < 0.15
        if !leanOk { issues.append("leaning forward") }

        // 2. Slouching: face drops lower
        let positionDrop = (Double(box.midY) - calibration.faceBBoxCenterY) / calibration.faceBBoxHeight
        let dropOk = positionDrop < 0.20
        if !dropOk { issues.append("slouching") }

        // 3. Head roll: eye-line angle deviation from calibrated
        let roll = face.eyeLineRoll ?? 0
        let rollDelta = abs(roll - calibration.calibratedRoll)
        let rollOk = rollDelta < 8.0
        if !rollOk { issues.append("head tilted") }

        // 4. Lateral lean: face center X drift from calibrated position
        let lateralDrift: Double
        if calibration.faceBBoxCenterX != 0 {
            lateralDrift = (Double(box.midX) - calibration.faceBBoxCenterX) / Double(box.width)
        } else {
            lateralDrift = 0
        }
        let lateralOk = abs(lateralDrift) < 0.25
        if !lateralOk {
            issues.append(lateralDrift > 0 ? "leaning right" : "leaning left")
        }

        // 5. Head yaw: nose offset from centered (informational)
        // Not penalized — turning head is natural during conversation

        let isGood = leanOk && dropOk && rollOk && lateralOk

        return Result(
            isGood: isGood,
            shoulderTilt: roll - calibration.calibratedRoll,
            headDropRatio: max(sizeChange, positionDrop),
            shoulderShrug: abs(lateralDrift),
            details: isGood ? "Good posture" : issues.joined(separator: ", "),
            source: .faceOnly
        )
    }

    /// Calibrate from snapshots — stores both body pose and face metrics.
    static func calibrate(from snapshots: [BodyLandmarks], face: FaceLandmarks? = nil) -> Calibration {
        let valid = snapshots.compactMap { lm -> (CGPoint, CGPoint, CGPoint)? in
            guard let n = lm.nose, let ls = lm.leftShoulder, let rs = lm.rightShoulder else { return nil }
            return (n, ls, rs)
        }

        var cal = Calibration()

        if !valid.isEmpty {
            let count = Double(valid.count)
            cal.noseY = valid.reduce(0.0) { $0 + $1.0.y } / count
            let avgShoulderMidY = valid.reduce(0.0) { $0 + ($1.1.y + $1.2.y) / CGFloat(2) } / count
            cal.shoulderMidY = avgShoulderMidY
            cal.shoulderAngle = valid.reduce(0.0) { $0 + LandmarkMath.angleDegrees(from: $1.1, to: $1.2) } / count
            cal.shoulderWidth = valid.reduce(0.0) { $0 + LandmarkMath.distance($1.1, $1.2) } / count

            // Scale-invariant ratio
            if cal.shoulderWidth > 0 {
                cal.headToShoulderRatio = valid.reduce(0.0) {
                    $0 + abs($1.0.y - ($1.1.y + $1.2.y) / CGFloat(2)) / CGFloat(cal.shoulderWidth)
                } / count
            }
        }

        // Face calibration
        if let face = face {
            cal.faceBBoxHeight = Double(face.boundingBox.height)
            cal.faceBBoxCenterY = Double(face.boundingBox.midY)
            cal.faceBBoxCenterX = Double(face.boundingBox.midX)
            cal.calibratedRoll = face.eyeLineRoll ?? 0
            cal.calibratedNoseOffset = face.noseOffsetRatio ?? 0
        }

        return cal
    }
}
