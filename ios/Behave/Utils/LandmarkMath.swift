import Foundation

/// Geometry utilities for landmark calculations.
enum LandmarkMath {

    /// Euclidean distance between two normalized points
    static func distance(_ a: CGPoint, _ b: CGPoint) -> Double {
        let dx = Double(a.x - b.x)
        let dy = Double(a.y - b.y)
        return sqrt(dx * dx + dy * dy)
    }

    /// Angle in degrees between two points relative to horizontal.
    static func angleDegrees(from a: CGPoint, to b: CGPoint) -> Double {
        let dx = Double(b.x - a.x)
        let dy = Double(b.y - a.y)
        return atan2(dy, dx) * 180.0 / .pi
    }

    /// Midpoint between two points
    static func midpoint(_ a: CGPoint, _ b: CGPoint) -> CGPoint {
        CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2)
    }

    /// Scale a normalized point (0-1) to a view size.
    /// Simple version — no aspect ratio correction.
    static func scale(_ point: CGPoint, to size: CGSize) -> CGPoint {
        CGPoint(x: point.x * size.width, y: point.y * size.height)
    }

    /// Scale a normalized rect to a view size.
    static func scale(_ rect: CGRect, to size: CGSize) -> CGRect {
        CGRect(
            x: rect.origin.x * size.width,
            y: rect.origin.y * size.height,
            width: rect.width * size.width,
            height: rect.height * size.height
        )
    }

    // MARK: - AspectFill-corrected conversions

    /// Convert a Vision normalized point to screen coordinates,
    /// accounting for resizeAspectFill cropping.
    ///
    /// The preview layer uses aspectFill: the image is zoomed so it fills
    /// the screen completely, cropping the sides (or top/bottom). Vision
    /// coordinates are in the full uncropped image space. This function
    /// maps from image space to screen space.
    static func visionToScreen(
        _ point: CGPoint,
        screenSize: CGSize,
        imageAspect: CGFloat
    ) -> CGPoint {
        let screenAspect = screenSize.width / screenSize.height

        let sx: CGFloat
        let sy: CGFloat

        if imageAspect > screenAspect {
            // Image wider than screen → sides cropped, height fills exactly
            let r = imageAspect / screenAspect
            sx = ((point.x - 0.5) * r + 0.5) * screenSize.width
            sy = point.y * screenSize.height
        } else {
            // Image taller than screen → top/bottom cropped, width fills exactly
            let r = screenAspect / imageAspect
            sx = point.x * screenSize.width
            sy = ((point.y - 0.5) * r + 0.5) * screenSize.height
        }

        return CGPoint(x: sx, y: sy)
    }

    /// Convert a Vision normalized rect to screen coordinates with aspectFill correction.
    static func visionToScreen(
        _ rect: CGRect,
        screenSize: CGSize,
        imageAspect: CGFloat
    ) -> CGRect {
        let origin = visionToScreen(rect.origin, screenSize: screenSize, imageAspect: imageAspect)
        let corner = visionToScreen(
            CGPoint(x: rect.maxX, y: rect.maxY),
            screenSize: screenSize,
            imageAspect: imageAspect
        )
        return CGRect(
            x: origin.x,
            y: origin.y,
            width: corner.x - origin.x,
            height: corner.y - origin.y
        )
    }
}
