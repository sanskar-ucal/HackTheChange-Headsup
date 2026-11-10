import ApplicationServices
import CoreGraphics
import Foundation

/// Posts scroll input.
@MainActor
public protocol ScrollController: AnyObject {
    func scroll(dx: Double, dy: Double, at point: CGPoint)
}

/// Pixel-precise scrolling via `CGEvent(scrollWheelEvent2Source:units:.pixel…)`.
@MainActor
public final class CGEventScrollController: ScrollController {
    private let source = CGEventSource(stateID: .hidSystemState)
    private var remainderX = 0.0
    private var remainderY = 0.0

    public init() {}

    public func scroll(dx: Double, dy: Double, at point: CGPoint) {
        guard AXIsProcessTrusted() else { return }
        remainderX += dx
        remainderY += dy
        let wholeX = Int32(remainderX.rounded(.towardZero))
        let wholeY = Int32(remainderY.rounded(.towardZero))
        guard wholeX != 0 || wholeY != 0 else { return }
        remainderX -= Double(wholeX)
        remainderY -= Double(wholeY)
        // Vertical-only scrolls use one wheel; the horizontal axis is added only when needed.
        let wheels: UInt32 = wholeX == 0 ? 1 : 2
        guard let event = CGEvent(scrollWheelEvent2Source: source, units: .pixel, wheelCount: wheels,
                                  wheel1: wholeY, wheel2: wholeX, wheel3: 0) else { return }
        // The window server routes scroll events by location: scroll what's under `point`.
        event.location = point
        event.post(tap: .cghidEventTap)
    }
}
