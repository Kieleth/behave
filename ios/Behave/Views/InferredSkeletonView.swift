import SwiftUI

/// Draws an inferred upper body skeleton from face landmarks.
/// Shows head circle, neck, shoulder ball joints, clavicles, and spine.
/// All geometry is estimated from face proportions and rotated by head roll.
struct InferredSkeletonView: View {
    let face: FaceLandmarks
    let screenSize: CGSize
    let imageAspect: CGFloat
    let status: BehaviorStatus

    private var color: Color {
        switch status {
        case .ok: return .green
        case .warning: return .yellow
        case .alert: return .red
        }
    }

    var body: some View {
        Canvas { context, _ in
            let box = face.boundingBox
            let roll = face.eyeLineRoll ?? 0  // degrees

            // Convert face landmarks to screen coordinates
            let headCenter = LandmarkMath.visionToScreen(
                CGPoint(x: box.midX, y: box.midY),
                screenSize: screenSize, imageAspect: imageAspect
            )

            let chin = LandmarkMath.visionToScreen(
                face.chinPoint ?? CGPoint(x: box.midX, y: box.maxY),
                screenSize: screenSize, imageAspect: imageAspect
            )

            let faceH = abs(chin.y - LandmarkMath.visionToScreen(
                CGPoint(x: box.midX, y: box.minY),
                screenSize: screenSize, imageAspect: imageAspect
            ).y)

            let faceW = abs(LandmarkMath.visionToScreen(
                CGPoint(x: box.maxX, y: box.midY),
                screenSize: screenSize, imageAspect: imageAspect
            ).x - LandmarkMath.visionToScreen(
                CGPoint(x: box.minX, y: box.midY),
                screenSize: screenSize, imageAspect: imageAspect
            ).x)

            guard faceH > 10 else { return }

            // Anthropometric estimates relative to face
            let neckLength = faceH * 0.4
            let shoulderDrop = faceH * 1.2       // shoulders below chin
            let shoulderHalfW = faceW * 1.4       // total shoulder = ~2.8x face width
            let spineLength = faceH * 2.0         // spine extends below chin
            let jointRadius: CGFloat = 8
            let rollRad = roll * .pi / 180

            // Neck base (below chin, centered)
            let neckBase = CGPoint(
                x: chin.x - sin(rollRad) * neckLength,
                y: chin.y + cos(rollRad) * neckLength
            )

            // Shoulder positions (rotated by roll)
            let shoulderCenter = CGPoint(
                x: chin.x - sin(rollRad) * shoulderDrop,
                y: chin.y + cos(rollRad) * shoulderDrop
            )
            let leftShoulder = CGPoint(
                x: shoulderCenter.x - cos(rollRad) * shoulderHalfW,
                y: shoulderCenter.y - sin(rollRad) * shoulderHalfW
            )
            let rightShoulder = CGPoint(
                x: shoulderCenter.x + cos(rollRad) * shoulderHalfW,
                y: shoulderCenter.y + sin(rollRad) * shoulderHalfW
            )

            // Spine end (torso center, below shoulders)
            let spineEnd = CGPoint(
                x: chin.x - sin(rollRad) * spineLength,
                y: chin.y + cos(rollRad) * spineLength
            )

            // --- Draw ---

            // Head circle
            let headRadius = faceW * 0.55
            let headRect = CGRect(
                x: headCenter.x - headRadius,
                y: headCenter.y - headRadius,
                width: headRadius * 2,
                height: headRadius * 2
            )
            context.stroke(Path(ellipseIn: headRect), with: .color(color.opacity(0.5)), lineWidth: 2)

            // Neck line (chin → neck base)
            var neckPath = Path()
            neckPath.move(to: chin)
            neckPath.addLine(to: neckBase)
            context.stroke(neckPath, with: .color(color.opacity(0.7)), lineWidth: 3)

            // Clavicle lines (neck base → each shoulder)
            for shoulder in [leftShoulder, rightShoulder] {
                var clavPath = Path()
                clavPath.move(to: neckBase)
                clavPath.addLine(to: shoulder)
                context.stroke(clavPath, with: .color(color.opacity(0.7)), lineWidth: 3)
            }

            // Shoulder bar (left → right, thick)
            var shoulderBar = Path()
            shoulderBar.move(to: leftShoulder)
            shoulderBar.addLine(to: rightShoulder)
            context.stroke(shoulderBar, with: .color(color), lineWidth: 4)

            // Shoulder ball joints
            for shoulder in [leftShoulder, rightShoulder] {
                // Outer ring
                let outerRect = CGRect(
                    x: shoulder.x - jointRadius,
                    y: shoulder.y - jointRadius,
                    width: jointRadius * 2,
                    height: jointRadius * 2
                )
                context.fill(Path(ellipseIn: outerRect), with: .color(color))
                // Inner white dot
                let innerR = jointRadius * 0.5
                let innerRect = CGRect(
                    x: shoulder.x - innerR,
                    y: shoulder.y - innerR,
                    width: innerR * 2,
                    height: innerR * 2
                )
                context.fill(Path(ellipseIn: innerRect), with: .color(.white.opacity(0.8)))
            }

            // Spine (dashed, from neck base down)
            var spinePath = Path()
            spinePath.move(to: neckBase)
            spinePath.addLine(to: spineEnd)
            context.stroke(
                spinePath, with: .color(color.opacity(0.4)),
                style: StrokeStyle(lineWidth: 2, dash: [8, 5])
            )

            // Neck base joint (small dot)
            let neckDot = CGRect(x: neckBase.x - 4, y: neckBase.y - 4, width: 8, height: 8)
            context.fill(Path(ellipseIn: neckDot), with: .color(color))
        }
    }
}
