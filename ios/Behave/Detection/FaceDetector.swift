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

        // Get buffer dimensions (landscape for front camera)
        let bufW = CVPixelBufferGetWidth(pixelBuffer)
        let bufH = CVPixelBufferGetHeight(pixelBuffer)

        // After orientation rotation, the "image" size is swapped for .right/.left
        let imageSize: CGSize
        switch orientation {
        case .right, .left, .rightMirrored, .leftMirrored:
            imageSize = CGSize(width: bufH, height: bufW)  // portrait
        default:
            imageSize = CGSize(width: bufW, height: bufH)
        }

        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: orientation)
        try? handler.perform([request])

        guard let observation = request.results?.first else {
            DispatchQueue.main.async {
                self.faceLandmarks = nil
                self.rawBoundingBox = .zero
            }
            return
        }

        let landmarks = FaceLandmarks(from: observation, imageSize: imageSize)
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

    init(from observation: VNFaceObservation, imageSize: CGSize) {
        // Bounding box: flip X for front-camera mirror, no Y flip
        // (empirically determined via diagnostic dots)
        let box = observation.boundingBox
        self.boundingBox = CGRect(
            x: 1 - box.origin.x - box.width,
            y: box.origin.y,
            width: box.width,
            height: box.height
        )

        let landmarks = observation.landmarks

        // Use Apple's pointsInImage(imageSize:) for landmark conversion.
        // Returns points with origin at upper-left in image pixel space.
        // Then normalize and flip X to match mirrored preview.
        func convert(_ region: VNFaceLandmarkRegion2D?) -> [CGPoint]? {
            guard let region = region else { return nil }
            let imgPoints = region.pointsInImage(imageSize: imageSize)
            return imgPoints.map { p in
                CGPoint(
                    x: 1 - (p.x / imageSize.width),   // flip X for mirror
                    y: p.y / imageSize.height
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
