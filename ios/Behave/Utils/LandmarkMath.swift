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
    /// Returns positive if right point is higher, negative if lower.
    static func angleDegrees(from a: CGPoint, to b: CGPoint) -> Double {
        let dx = Double(b.x - a.x)
        let dy = Double(b.y - a.y)
        return atan2(dy, dx) * 180.0 / .pi
    }

    /// Midpoint between two points
    static func midpoint(_ a: CGPoint, _ b: CGPoint) -> CGPoint {
        CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2)
    }

    /// Scale a normalized point (0-1) to a view size
    static func scale(_ point: CGPoint, to size: CGSize) -> CGPoint {
        CGPoint(x: point.x * size.width, y: point.y * size.height)
    }

    /// Scale a normalized rect to a view size
    static func scale(_ rect: CGRect, to size: CGSize) -> CGRect {
        CGRect(
            x: rect.origin.x * size.width,
            y: rect.origin.y * size.height,
            width: rect.width * size.width,
            height: rect.height * size.height
        )
    }
}
