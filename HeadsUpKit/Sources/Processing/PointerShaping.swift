import Foundation

/// Hold-only dead zone for absolute pointing.
///
/// While the head moves, the output is exactly the input, so the mapping is never offset.
/// Once the head has stayed within `width` of the last movement for `settleTime`, the
/// output holds the pose at that moment, so small tremor doesn't jiggle the pointer. The
/// hold is refreshed once more after another `settleTime` (if it is off by more than a sixth
/// of `width`), so the smoothing filter's last bit of convergence doesn't leave it off.
/// Moving more than `width` releases the hold, and the output is the exact input again.
/// The output is always an actual recent pose, never an accumulated or trailing value.
public struct StillnessHold: Sendable {
    public var width: Double
    public var settleTime: TimeInterval

    private var anchorX = 0.0, anchorY = 0.0
    private var lastMoveTime: TimeInterval = 0
    private var hasAnchor = false
    private var held: (x: Double, y: Double)?
    private var heldAt: TimeInterval = 0
    private var refreshed = false

    public init(width: Double, settleTime: TimeInterval) {
        self.width = width
        self.settleTime = settleTime
    }

    public mutating func reset() {
        hasAnchor = false
        held = nil
    }

    public var isHolding: Bool { held != nil }

    public mutating func apply(x: Double, y: Double, time: TimeInterval) -> (x: Double, y: Double) {
        let dx = x - anchorX, dy = y - anchorY
        if !hasAnchor || (dx * dx + dy * dy).squareRoot() > width {
            anchorX = x
            anchorY = y
            lastMoveTime = time
            hasAnchor = true
            held = nil
            return (x, y)
        }
        if let current = held {
            guard !refreshed, time - heldAt >= settleTime else { return current }
            refreshed = true
            // Only correct a real residual (filter still converging), not sensor noise.
            let rx = x - current.x, ry = y - current.y
            guard (rx * rx + ry * ry).squareRoot() >= width / 6 else { return current }
            held = (x, y)
            return (x, y)
        }
        if time - lastMoveTime >= settleTime {
            held = (x, y)
            heldAt = time
            refreshed = false
        }
        return (x, y)
    }
}
