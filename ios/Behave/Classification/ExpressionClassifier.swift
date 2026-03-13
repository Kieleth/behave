import Foundation

/// Classifies facial expressions from face landmarks.
/// Detects tension indicators: frowning, jaw clenching, raised eyebrows.
struct ExpressionClassifier {

    struct Result {
        let dominantExpression: Expression
        let tension: Double            // 0-1 tension score
        let details: String
    }

    enum Expression: String {
        case neutral
        case frowning
        case tense
        case surprised
        case unknown
    }

    func classify(faceLandmarks: FaceLandmarks) -> Result {
        // Analyze eyebrow-to-eye distance for raised eyebrows / frowning
        guard let leftEyebrow = faceLandmarks.leftEyebrow,
              let rightEyebrow = faceLandmarks.rightEyebrow,
              let leftEye = faceLandmarks.leftEye,
              let rightEye = faceLandmarks.rightEye else {
            return Result(dominantExpression: .unknown, tension: 0, details: "Insufficient landmarks")
        }

        // Average eyebrow height relative to eye
        let leftBrowEyeDist = averageDistance(leftEyebrow, leftEye)
        let rightBrowEyeDist = averageDistance(rightEyebrow, rightEye)
        let browHeight = (leftBrowEyeDist + rightBrowEyeDist) / 2

        // Mouth analysis for jaw tension
        let mouthOpenness = mouthOpenRatio(faceLandmarks)

        // Classify based on landmark geometry
        var tension: Double = 0
        var expression: Expression = .neutral

        // Low brow height = frowning
        if browHeight < 0.015 {
            expression = .frowning
            tension = 0.7
        }
        // High brow height = surprised
        else if browHeight > 0.04 {
            expression = .surprised
            tension = 0.3
        }
        // Jaw clenched (mouth very closed with tension)
        if mouthOpenness < 0.005 && expression == .neutral {
            expression = .tense
            tension = 0.5
        }

        let details = expression == .neutral ? "Relaxed" : expression.rawValue.capitalized

        return Result(dominantExpression: expression, tension: tension, details: details)
    }

    private func averageDistance(_ group1: [CGPoint], _ group2: [CGPoint]) -> Double {
        guard !group1.isEmpty, !group2.isEmpty else { return 0 }
        let center1 = CGPoint(
            x: group1.reduce(0) { $0 + $1.x } / CGFloat(group1.count),
            y: group1.reduce(0) { $0 + $1.y } / CGFloat(group1.count)
        )
        let center2 = CGPoint(
            x: group2.reduce(0) { $0 + $1.x } / CGFloat(group2.count),
            y: group2.reduce(0) { $0 + $1.y } / CGFloat(group2.count)
        )
        return LandmarkMath.distance(center1, center2)
    }

    private func mouthOpenRatio(_ face: FaceLandmarks) -> Double {
        guard let outer = face.outerLips, let inner = face.innerLips,
              outer.count >= 6, inner.count >= 4 else { return 0 }
        // Vertical opening relative to mouth width
        let outerHeight = abs(outer[3].y - outer[0].y)
        let innerHeight = abs(inner[2].y - inner[0].y)
        return Double(innerHeight / max(outerHeight, 0.001))
    }
}
