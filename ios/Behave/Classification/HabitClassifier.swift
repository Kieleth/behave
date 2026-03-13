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

    /// Proximity threshold (normalized coordinates).
    /// Fingertips within this distance of mouth = nail biting.
    var mouthProximityThreshold: Double = 0.06
    var faceProximityThreshold: Double = 0.10
    var hairProximityThreshold: Double = 0.08

    func classify(hands: [HandLandmarks], face: FaceLandmarks?) -> Result {
        guard let face = face else {
            return Result(detectedHabits: [], details: "No face detected")
        }

        var habits: [Habit] = []

        for hand in hands {
            // Nail biting: fingertips near mouth
            if let mouthCenter = face.mouthCenter {
                for tip in hand.fingertips {
                    let dist = LandmarkMath.distance(tip, mouthCenter)
                    if dist < mouthProximityThreshold {
                        let confidence = 1.0 - (dist / mouthProximityThreshold)
                        habits.append(Habit(type: .nailBiting, confidence: confidence))
                        break // one detection per hand is enough
                    }
                }
            }

            // Face touching: any fingertip near face bounding box center
            let faceCenter = CGPoint(
                x: face.boundingBox.midX,
                y: face.boundingBox.midY
            )
            for tip in hand.fingertips {
                let dist = LandmarkMath.distance(tip, faceCenter)
                if dist < faceProximityThreshold && !habits.contains(where: { $0.type == .nailBiting }) {
                    let confidence = 1.0 - (dist / faceProximityThreshold)
                    habits.append(Habit(type: .faceTouching, confidence: confidence))
                    break
                }
            }

            // Hair touching: wrist or fingertips above face bounding box top
            let faceTop = face.boundingBox.minY
            if let wrist = hand.wrist, wrist.y < faceTop {
                habits.append(Habit(type: .hairTouching, confidence: 0.6))
            }
        }

        let details = habits.isEmpty
            ? "No habits detected"
            : habits.map { $0.type.rawValue.replacingOccurrences(of: "_", with: " ") }.joined(separator: ", ")

        return Result(detectedHabits: habits, details: details)
    }
}
