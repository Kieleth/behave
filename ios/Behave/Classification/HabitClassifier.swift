import Foundation

/// Classifies habits by analyzing hand-to-face proximity.
/// Detects: nail biting, face touching, hair pulling.
struct HabitClassifier {

    struct Result {
        let detectedHabits: [Habit]
        let details: String
    }

    struct Habit {
        let type: HabitType
        let confidence: Double
    }

    enum HabitType: String {
        case nailBiting = "nail_biting"
        case faceTouching = "face_touching"
        case hairTouching = "hair_touching"
    }

    /// Proximity thresholds (normalized coordinates).
    /// These are relative to the face bounding box size for scale invariance.
    var mouthProximityFactor: Double = 0.5    // within 50% of face width from any lip point
    var faceProximityFactor: Double = 0.3     // within 30% of face width from face center
    var hairProximityFactor: Double = 0.2     // above face top by 20% of face height

    /// Temporal smoothing: require N consecutive frames of detection
    private var nailBitingFrames: Int = 0
    private var faceTouchingFrames: Int = 0
    private let requiredFrames = 2  // ~0.6s at 3-frame skip on 30fps

    mutating func classify(hands: [HandLandmarks], face: FaceLandmarks?) -> Result {
        guard let face = face else {
            nailBitingFrames = 0
            faceTouchingFrames = 0
            return Result(detectedHabits: [], details: "No face detected")
        }

        var habits: [Habit] = []
        let faceWidth = Double(face.boundingBox.width)
        guard faceWidth > 0.01 else {
            return Result(detectedHabits: [], details: "Face too small")
        }

        var nailBitingDetected = false
        var faceTouchingDetected = false

        for hand in hands {
            // Get ALL finger joint positions (not just tips — whole hand near face matters)
            let allPoints = Array(hand.allPoints.values)

            // Nail biting: any finger joint near any lip point
            if let outerLips = face.outerLips, !outerLips.isEmpty {
                let mouthThreshold = faceWidth * mouthProximityFactor
                var minDist = Double.infinity

                for joint in allPoints {
                    for lip in outerLips {
                        let dist = LandmarkMath.distance(joint, lip)
                        minDist = min(minDist, dist)
                    }
                }

                if minDist < mouthThreshold {
                    nailBitingDetected = true
                    let confidence = 1.0 - (minDist / mouthThreshold)
                    habits.append(Habit(type: .nailBiting, confidence: confidence))
                }
            }

            // Face touching: any finger joint inside or near face bounding box
            if !nailBitingDetected {
                let faceThreshold = faceWidth * faceProximityFactor
                let faceCenter = CGPoint(x: face.boundingBox.midX, y: face.boundingBox.midY)

                for joint in allPoints {
                    // Check if point is within expanded face bounding box
                    let expandedBox = face.boundingBox.insetBy(
                        dx: -CGFloat(faceThreshold),
                        dy: -CGFloat(faceThreshold)
                    )
                    if expandedBox.contains(joint) {
                        faceTouchingDetected = true
                        let dist = LandmarkMath.distance(joint, faceCenter)
                        let confidence = max(0.3, 1.0 - (dist / (faceWidth * 0.8)))
                        habits.append(Habit(type: .faceTouching, confidence: confidence))
                        break
                    }
                }
            }

            // Hair touching: wrist or fingertips above face top
            let faceTop = Double(face.boundingBox.minY)
            let hairThreshold = Double(face.boundingBox.height) * hairProximityFactor
            if let wrist = hand.wrist, Double(wrist.y) < faceTop - hairThreshold {
                habits.append(Habit(type: .hairTouching, confidence: 0.6))
            } else {
                for tip in hand.fingertips {
                    if Double(tip.y) < faceTop - hairThreshold {
                        habits.append(Habit(type: .hairTouching, confidence: 0.5))
                        break
                    }
                }
            }
        }

        // Temporal smoothing: only report after sustained detection
        nailBitingFrames = nailBitingDetected ? nailBitingFrames + 1 : 0
        faceTouchingFrames = faceTouchingDetected ? faceTouchingFrames + 1 : 0

        var smoothedHabits: [Habit] = []
        if nailBitingFrames >= requiredFrames {
            if let h = habits.first(where: { $0.type == .nailBiting }) {
                smoothedHabits.append(h)
            }
        }
        if faceTouchingFrames >= requiredFrames {
            if let h = habits.first(where: { $0.type == .faceTouching }) {
                smoothedHabits.append(h)
            }
        }
        // Hair touching doesn't need temporal smoothing (less common false positive)
        smoothedHabits.append(contentsOf: habits.filter { $0.type == .hairTouching })

        let details = smoothedHabits.isEmpty
            ? "No habits detected"
            : smoothedHabits.map { $0.type.rawValue.replacingOccurrences(of: "_", with: " ") }.joined(separator: ", ")

        return Result(detectedHabits: smoothedHabits, details: details)
    }
}
