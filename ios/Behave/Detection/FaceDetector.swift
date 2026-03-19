import Vision
import CoreMedia
import Combine

/// Detects face landmarks (76 points) and optionally ARKit blend shapes.
final class FaceDetector: ObservableObject {
    @Published var faceLandmarks: FaceLandmarks?

    /// Raw Vision bounding box for diagnostics (before any transform).
    @Published var rawBoundingBox: CGRect = .zero

    private let request: VNDetectFaceLandmarksRequest = {
        let req = VNDetectFaceLandmarksRequest()
        return req
    }()

    func detect(in sampleBuffer: CMSampleBuffer, orientation: CGImagePropertyOrientation = .right) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: orientation)
        try? handler.perform([request])

        guard let observation = request.results?.first else {
            DispatchQueue.main.async {
                self.faceLandmarks = nil
                self.rawBoundingBox = .zero
            }
            return
        }

        let landmarks = FaceLandmarks(from: observation)
        DispatchQueue.main.async {
            self.faceLandmarks = landmarks
            self.rawBoundingBox = observation.boundingBox
        }
    }
}

/// Extracted face landmark data from Vision observation.
struct FaceLandmarks {
    let boundingBox: CGRect
    let leftEye: [CGPoint]?
    let rightEye: [CGPoint]?
    let outerLips: [CGPoint]?
    let innerLips: [CGPoint]?
    let leftEyebrow: [CGPoint]?
    let rightEyebrow: [CGPoint]?
    let nose: [CGPoint]?
    let faceContour: [CGPoint]?

    /// Mouth center (normalized) — used for nail biting proximity check
    var mouthCenter: CGPoint? {
        guard let lips = outerLips, !lips.isEmpty else { return nil }
        let sumX = lips.reduce(0.0) { $0 + $1.x }
        let sumY = lips.reduce(0.0) { $0 + $1.y }
        return CGPoint(x: sumX / CGFloat(lips.count), y: sumY / CGFloat(lips.count))
    }

    // MARK: - Geometry helpers for posture inference

    /// Head roll in degrees from the eye-to-eye line. 0 = level, positive = tilting right.
    var eyeLineRoll: Double? {
        guard let le = leftEye, let re = rightEye, !le.isEmpty, !re.isEmpty else { return nil }
        let lc = centroid(le)
        let rc = centroid(re)
        return LandmarkMath.angleDegrees(from: lc, to: rc)
    }

    /// Nose X offset as fraction of face width. 0 = centered, negative = left, positive = right.
    var noseOffsetRatio: Double? {
        guard let nosePts = nose, !nosePts.isEmpty else { return nil }
        let noseX = nosePts.map(\.x).reduce(0, +) / CGFloat(nosePts.count)
        return Double(noseX - boundingBox.midX) / Double(boundingBox.width)
    }

    /// Eye width asymmetry: left eye width / right eye width. 1.0 = symmetric.
    /// < 1.0 = head turned right (left eye appears smaller).
    var eyeWidthAsymmetry: Double? {
        guard let le = leftEye, let re = rightEye, !le.isEmpty, !re.isEmpty else { return nil }
        let leftW = (le.map(\.x).max() ?? 0) - (le.map(\.x).min() ?? 0)
        let rightW = (re.map(\.x).max() ?? 0) - (re.map(\.x).min() ?? 0)
        guard rightW > 0.001 else { return nil }
        return Double(leftW / rightW)
    }

    /// Pitch proxy: nose-to-eye-center distance / face height. Larger = looking down.
    var pitchProxy: Double? {
        guard let le = leftEye, let re = rightEye, !le.isEmpty, !re.isEmpty,
              let nosePts = nose, !nosePts.isEmpty else { return nil }
        let eyeCenter = LandmarkMath.midpoint(centroid(le), centroid(re))
        let noseTip = nosePts.last ?? nosePts[0]
        let dist = LandmarkMath.distance(eyeCenter, noseTip)
        guard boundingBox.height > 0.001 else { return nil }
        return dist / Double(boundingBox.height)
    }

    /// Chin point — lowest point on face contour (neck/shoulder anchor).
    var chinPoint: CGPoint? {
        guard let contour = faceContour, !contour.isEmpty else {
            // Fallback: bottom center of bounding box
            return CGPoint(x: boundingBox.midX, y: boundingBox.maxY)
        }
        return contour.max(by: { $0.y < $1.y })
    }

    /// Left eye center
    var leftEyeCenter: CGPoint? {
        guard let le = leftEye, !le.isEmpty else { return nil }
        return centroid(le)
    }

    /// Right eye center
    var rightEyeCenter: CGPoint? {
        guard let re = rightEye, !re.isEmpty else { return nil }
        return centroid(re)
    }

    private func centroid(_ points: [CGPoint]) -> CGPoint {
        let n = CGFloat(points.count)
        return CGPoint(
            x: points.map(\.x).reduce(0, +) / n,
            y: points.map(\.y).reduce(0, +) / n
        )
    }

    init(from observation: VNFaceObservation) {
        // Bounding box: flip X for front-camera mirror, no Y flip
        // (empirically determined via diagnostic dots)
        let box = observation.boundingBox
        self.boundingBox = CGRect(
            x: 1 - box.origin.x - box.width,
            y: box.origin.y,
            width: box.width,
            height: box.height
        )

        // Transformed box left edge (already X-flipped)
        let tbx = 1 - box.origin.x - box.width

        let landmarks = observation.landmarks

        // normalizedPoints are 0-1 relative to the raw Vision bounding box.
        // Flip X within the box to match the mirrored preview.
        func convert(_ region: VNFaceLandmarkRegion2D?) -> [CGPoint]? {
            guard let region = region else { return nil }
            return region.normalizedPoints.map { p in
                CGPoint(
                    x: tbx + (1 - p.x) * box.width,  // flip X within box for mirror
                    y: box.origin.y + p.y * box.height
                )
            }
        }

        self.leftEye = convert(landmarks?.leftEye)
        self.rightEye = convert(landmarks?.rightEye)
        self.outerLips = convert(landmarks?.outerLips)
        self.innerLips = convert(landmarks?.innerLips)
        self.leftEyebrow = convert(landmarks?.leftEyebrow)
        self.rightEyebrow = convert(landmarks?.rightEyebrow)
        self.nose = convert(landmarks?.nose)
        self.faceContour = convert(landmarks?.faceContour)
    }
}
