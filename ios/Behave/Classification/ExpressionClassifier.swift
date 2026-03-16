import Foundation

/// Classifies facial expressions from face landmarks.
/// Detects tension, gaze direction, eye state (squinting/closed).
struct ExpressionClassifier {

    struct Result {
        let dominantExpression: Expression
        let tension: Double            // 0-1 tension score
        let eyeOpenness: Double        // 0 = closed, 1 = fully open
        let isSquinting: Bool          // intense focus squint
        let isLookingAway: Bool        // not looking at screen
        let gazeDirection: GazeDirection
        let details: String
    }

    enum Expression: String {
        case neutral, frowning, tense, surprised, unknown
    }

    enum GazeDirection: String {
        case center, left, right, down, unknown
    }

    /// Thresholds
    var squintThreshold: Double = 0.15     // EAR below this = squinting
    var closedThreshold: Double = 0.08     // EAR below this = eyes closed
    var gazeOffsetThreshold: Double = 0.15 // face center offset from screen center

    func classify(faceLandmarks face: FaceLandmarks) -> Result {
        guard let leftEyebrow = face.leftEyebrow,
              let rightEyebrow = face.rightEyebrow,
              let leftEye = face.leftEye,
              let rightEye = face.rightEye else {
            return Result(dominantExpression: .unknown, tension: 0, eyeOpenness: 1,
                         isSquinting: false, isLookingAway: false,
                         gazeDirection: .unknown, details: "Insufficient landmarks")
        }

        // --- Eye Openness (Eye Aspect Ratio) ---
        let leftEAR = eyeAspectRatio(leftEye)
        let rightEAR = eyeAspectRatio(rightEye)
        let avgEAR = (leftEAR + rightEAR) / 2
        let eyeOpenness = min(1.0, avgEAR / 0.3)  // normalize: 0.3 EAR = fully open
        let isSquinting = avgEAR < squintThreshold && avgEAR >= closedThreshold
        let eyesClosed = avgEAR < closedThreshold

        // --- Gaze Direction ---
        let faceCenter = CGPoint(x: face.boundingBox.midX, y: face.boundingBox.midY)
        let screenCenterX: CGFloat = 0.5
        let xOffset = Double(faceCenter.x) - Double(screenCenterX)

        let gazeDirection: GazeDirection
        let isLookingAway: Bool
        if abs(xOffset) > gazeOffsetThreshold {
            gazeDirection = xOffset > 0 ? .right : .left
            isLookingAway = true
        } else if Double(faceCenter.y) > 0.65 {
            gazeDirection = .down
            isLookingAway = true
        } else {
            gazeDirection = .center
            isLookingAway = false
        }

        // --- Expression (brow + mouth analysis) ---
        let browHeight = averageDistance(leftEyebrow, leftEye) +
                         averageDistance(rightEyebrow, rightEye)
        let browAvg = browHeight / 2
        let mouthOpen = mouthOpenRatio(face)

        var tension: Double = 0
        var expression: Expression = .neutral

        if browAvg < 0.015 {
            expression = .frowning
            tension = 0.7
        } else if browAvg > 0.04 {
            expression = .surprised
            tension = 0.3
        }

        if mouthOpen < 0.005 && expression == .neutral {
            expression = .tense
            tension = 0.5
        }

        // Squinting adds tension
        if isSquinting {
            tension = max(tension, 0.6)
            if expression == .neutral { expression = .tense }
        }
        if eyesClosed {
            tension = max(tension, 0.8)
        }

        // Details
        var issues: [String] = []
        if expression != .neutral { issues.append(expression.rawValue) }
        if isSquinting { issues.append("squinting") }
        if eyesClosed { issues.append("eyes closed") }
        if isLookingAway { issues.append("looking \(gazeDirection.rawValue)") }
        let details = issues.isEmpty ? "Relaxed" : issues.joined(separator: ", ")

        return Result(
            dominantExpression: expression,
            tension: tension,
            eyeOpenness: eyeOpenness,
            isSquinting: isSquinting,
            isLookingAway: isLookingAway,
            gazeDirection: gazeDirection,
            details: details
        )
    }

    // MARK: - Eye Aspect Ratio

    /// Computes Eye Aspect Ratio (EAR) from eye landmark points.
    /// EAR = average vertical span / horizontal span.
    /// Low EAR = closed/squinting, high EAR = open.
    private func eyeAspectRatio(_ eyePoints: [CGPoint]) -> Double {
        guard eyePoints.count >= 6 else { return 0.3 } // default to "open" if insufficient

        // Eye points roughly form an ellipse.
        // Horizontal: distance between leftmost and rightmost points
        let xs = eyePoints.map { $0.x }
        let ys = eyePoints.map { $0.y }
        let horizontalSpan = Double((xs.max() ?? 0) - (xs.min() ?? 0))
        let verticalSpan = Double((ys.max() ?? 0) - (ys.min() ?? 0))

        guard horizontalSpan > 0.001 else { return 0.3 }
        return verticalSpan / horizontalSpan
    }

    // MARK: - Helpers

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
        let outerHeight = abs(outer[3].y - outer[0].y)
        let innerHeight = abs(inner[2].y - inner[0].y)
        return Double(innerHeight / max(outerHeight, 0.001))
    }
}
