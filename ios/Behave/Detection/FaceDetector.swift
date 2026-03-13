import Vision
import CoreMedia
import Combine

/// Detects face landmarks (76 points) and optionally ARKit blend shapes.
final class FaceDetector: ObservableObject {
    @Published var faceLandmarks: FaceLandmarks?

    private let request: VNDetectFaceLandmarksRequest = {
        let req = VNDetectFaceLandmarksRequest()
        return req
    }()

    func detect(in sampleBuffer: CMSampleBuffer) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up)
        try? handler.perform([request])

        guard let observation = request.results?.first else {
            DispatchQueue.main.async { self.faceLandmarks = nil }
            return
        }

        let landmarks = FaceLandmarks(from: observation)
        DispatchQueue.main.async { self.faceLandmarks = landmarks }
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

    init(from observation: VNFaceObservation) {
        // Bounding box: convert from bottom-left origin to top-left
        let box = observation.boundingBox
        self.boundingBox = CGRect(
            x: box.origin.x,
            y: 1 - box.origin.y - box.height,
            width: box.width,
            height: box.height
        )

        let landmarks = observation.landmarks

        func convert(_ region: VNFaceLandmarkRegion2D?) -> [CGPoint]? {
            guard let region = region else { return nil }
            return region.normalizedPoints.map { p in
                // Points are relative to bounding box, convert to image coordinates
                CGPoint(
                    x: box.origin.x + p.x * box.width,
                    y: 1 - (box.origin.y + p.y * box.height)
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
