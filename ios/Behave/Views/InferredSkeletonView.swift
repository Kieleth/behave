import SwiftUI

/// Draws an inferred upper body skeleton from face landmarks.
/// Head rotates with eye-line tilt. Shoulders/spine stay level (decoupled).
/// If user-taught shoulder positions exist (from calibration taps), uses those.
struct InferredSkeletonView: View {
    let face: FaceLandmarks
    let screenSize: CGSize
    let imageAspect: CGFloat
    let status: BehaviorStatus
    /// User-taught shoulder positions (normalized 0-1). Nil = use estimates.
    var taughtLeftShoulder: CGPoint?
    var taughtRightShoulder: CGPoint?

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
            let roll = face.eyeLineRoll ?? 0
            let rollRad = roll * .pi / 180

            // Face landmarks → screen coordinates
            let headCenter = v2s(CGPoint(x: box.midX, y: box.midY))
            let chin = v2s(face.chinPoint ?? CGPoint(x: box.midX, y: box.maxY))
            let faceTop = v2s(CGPoint(x: box.midX, y: box.minY))

            let faceH = abs(chin.y - faceTop.y)
            let faceW = abs(v2s(CGPoint(x: box.maxX, y: 0)).x - v2s(CGPoint(x: box.minX, y: 0)).x)
            guard faceH > 10 else { return }

            // --- Head + neck: rotated by head roll ---
            let neckLength = faceH * 0.35
            let neckBase = CGPoint(
                x: chin.x - sin(rollRad) * neckLength,
                y: chin.y + cos(rollRad) * neckLength
            )

            // Head circle (rotates with head)
            let headRadius = faceW * 0.5
            drawCircle(context, center: headCenter, radius: headRadius, stroke: color.opacity(0.4), lineWidth: 2)

            // Neck line
            drawLine(context, from: chin, to: neckBase, color: color.opacity(0.6), width: 3)

            // --- Shoulders + spine: NOT rotated (stay level) ---
            // Shoulders anchored below the neck base, but horizontally level

            let shoulderY = neckBase.y + faceH * 0.15  // slight drop below neck
            let shoulderHalfW = faceW * 1.8  // humerous head = wider than armpits

            let leftShoulder: CGPoint
            let rightShoulder: CGPoint

            if let tl = taughtLeftShoulder, let tr = taughtRightShoulder {
                // User-taught positions
                leftShoulder = v2s(tl)
                rightShoulder = v2s(tr)
            } else {
                // Estimated — level, not rotated with head
                leftShoulder = CGPoint(x: neckBase.x - shoulderHalfW, y: shoulderY)
                rightShoulder = CGPoint(x: neckBase.x + shoulderHalfW, y: shoulderY)
            }

            let shoulderCenter = CGPoint(
                x: (leftShoulder.x + rightShoulder.x) / 2,
                y: (leftShoulder.y + rightShoulder.y) / 2
            )

            // Clavicle lines (neck → shoulders)
            drawLine(context, from: neckBase, to: leftShoulder, color: color.opacity(0.6), width: 2.5)
            drawLine(context, from: neckBase, to: rightShoulder, color: color.opacity(0.6), width: 2.5)

            // Shoulder bar
            drawLine(context, from: leftShoulder, to: rightShoulder, color: color, width: 4)

            // Shoulder ball joints (humerous heads)
            for shoulder in [leftShoulder, rightShoulder] {
                drawCircle(context, center: shoulder, radius: 9, fill: color)
                drawCircle(context, center: shoulder, radius: 4, fill: .white.opacity(0.8))
            }

            // Spine (dashed, from neck base straight down — not rotated)
            let spineEnd = CGPoint(x: shoulderCenter.x, y: shoulderCenter.y + faceH * 1.2)
            drawDashedLine(context, from: neckBase, to: spineEnd, color: color.opacity(0.35), width: 2)

            // Neck base dot
            drawCircle(context, center: neckBase, radius: 4, fill: color)
        }
    }

    // MARK: - Helpers

    private func v2s(_ point: CGPoint) -> CGPoint {
        LandmarkMath.visionToScreen(point, screenSize: screenSize, imageAspect: imageAspect)
    }

    private func drawLine(_ ctx: GraphicsContext, from: CGPoint, to: CGPoint, color: Color, width: CGFloat) {
        var path = Path()
        path.move(to: from)
        path.addLine(to: to)
        ctx.stroke(path, with: .color(color), lineWidth: width)
    }

    private func drawDashedLine(_ ctx: GraphicsContext, from: CGPoint, to: CGPoint, color: Color, width: CGFloat) {
        var path = Path()
        path.move(to: from)
        path.addLine(to: to)
        ctx.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: width, dash: [8, 5]))
    }

    private func drawCircle(_ ctx: GraphicsContext, center: CGPoint, radius: CGFloat, stroke: Color? = nil, fill: Color? = nil, lineWidth: CGFloat = 2) {
        let rect = CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
        if let fill {
            ctx.fill(Path(ellipseIn: rect), with: .color(fill))
        }
        if let stroke {
            ctx.stroke(Path(ellipseIn: rect), with: .color(stroke), lineWidth: lineWidth)
        }
    }
}
