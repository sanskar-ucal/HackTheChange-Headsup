import CoreGraphics
import Foundation

/// Display layout in the **global CoreGraphics space** (top-left origin, y grows down).
public struct ScreenGeometry: Sendable, Equatable {
    /// Display rectangles in global top-left coordinates.
    public let displays: [CGRect]
    /// The display with the menu bar (global origin 0,0).
    public let mainDisplay: CGRect

    public init(displays: [CGRect], mainDisplay: CGRect? = nil) {
        let fallback = CGRect(x: 0, y: 0, width: 1440, height: 900)
        let list = displays.isEmpty ? [mainDisplay ?? fallback] : displays
        self.displays = list
        self.mainDisplay = mainDisplay ?? list.first(where: { $0.origin == .zero }) ?? list[0]
    }

    /// The live display configuration.
    public static func current() -> ScreenGeometry {
        var count: UInt32 = 0
        guard CGGetActiveDisplayList(0, nil, &count) == .success, count > 0 else {
            return ScreenGeometry(displays: [])
        }
        var ids = [CGDirectDisplayID](repeating: 0, count: Int(count))
        guard CGGetActiveDisplayList(count, &ids, &count) == .success else {
            return ScreenGeometry(displays: [])
        }
        let rects = ids.prefix(Int(count)).map { CGDisplayBounds($0) }
        return ScreenGeometry(displays: rects, mainDisplay: CGDisplayBounds(CGMainDisplayID()))
    }

    public var unionBounds: CGRect {
        displays.dropFirst().reduce(displays[0]) { $0.union($1) }
    }

    /// The rectangle head pointing maps onto.
    public func pointingRect(spanAllDisplays: Bool) -> CGRect {
        spanAllDisplays ? unionBounds : mainDisplay
    }

    public func point(for normalized: NormalizedPoint, in rect: CGRect) -> CGPoint {
        CGPoint(x: rect.minX + normalized.x * rect.width,
                y: rect.minY + normalized.y * rect.height)
    }

    /// Moves `point` onto the nearest pixel of any display, since the union of displays can have holes.
    public func clamp(_ point: CGPoint) -> CGPoint {
        var best = point
        var bestDistance = CGFloat.infinity
        for rect in displays {
            let clamped = CGPoint(
                x: min(max(point.x, rect.minX), rect.maxX - 1),
                y: min(max(point.y, rect.minY), rect.maxY - 1))
            let distance = hypot(clamped.x - point.x, clamped.y - point.y)
            if distance < bestDistance {
                bestDistance = distance
                best = clamped
            }
            if distance == 0 { break }
        }
        return best
    }

    // MARK: AppKit conversion (bottom-left origin, relative to the main display)

    public func appKitRect(fromGlobal rect: CGRect) -> CGRect {
        CGRect(x: rect.minX, y: mainDisplay.height - rect.maxY, width: rect.width, height: rect.height)
    }

    public func globalRect(fromAppKit rect: CGRect) -> CGRect {
        CGRect(x: rect.minX, y: mainDisplay.height - rect.maxY, width: rect.width, height: rect.height)
    }

    public func appKitPoint(fromGlobal point: CGPoint) -> CGPoint {
        CGPoint(x: point.x, y: mainDisplay.height - point.y)
    }

    public func globalPoint(fromAppKit point: CGPoint) -> CGPoint {
        CGPoint(x: point.x, y: mainDisplay.height - point.y)
    }
}
