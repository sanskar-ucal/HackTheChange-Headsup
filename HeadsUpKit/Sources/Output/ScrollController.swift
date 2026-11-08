import ApplicationServices
import CoreGraphics
import Foundation

/// Posts scroll input. Deltas are pixels; positive `dy` reveals content above (wheel up),
/// positive `dx` reveals content to the left.
@MainActor
public protocol ScrollController: AnyObject {
    func scroll(dx: Double, dy: Double, at point: CGPoint)
}

/// Pixel-precise scrolling via `CGEvent(scrollWheelEvent2Source:units:.pixel…)`. Called
/// once per display frame with small deltas; fractional pixels are carried over so slow
/// speeds still scroll smoothly.
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
        guard let event = CGEvent(scrollWheelEvent2Source: source, units: .pixel, wheelCount: 2,
                                  wheel1: wholeY, wheel2: wholeX, wheel3: 0) else { return }
        // The window server routes scroll events by location: scroll what's under `point`.
        event.location = point
        event.post(tap: .cghidEventTap)
    }
}
