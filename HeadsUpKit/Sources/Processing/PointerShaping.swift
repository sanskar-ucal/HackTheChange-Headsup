import Foundation

/// 2-D backlash with hysteresis: while moving, the output trails the input by at most
/// `movingWidth`. Once the output has been still for `settleTime`, the input must move
/// `startWidth` before the output moves again, so small noise can't make it creep.
/// Units are whatever the caller uses (radians in `PointerMapper`).
public struct HysteresisDeadband: Sendable {
    public var movingWidth: Double
    public var startWidth: Double
    public var settleTime: TimeInterval

    private var heldX = 0.0
    private var heldY = 0.0
    private var hasValue = false
    private var isMoving = false
    private var lastMoveTime: TimeInterval = 0

    public init(movingWidth: Double, startWidth: Double, settleTime: TimeInterval) {
        self.movingWidth = movingWidth
        self.startWidth = startWidth
        self.settleTime = settleTime
    }

    public mutating func reset() {
        hasValue = false
        isMoving = false
    }

    public mutating func apply(x: Double, y: Double, time: TimeInterval) -> (x: Double, y: Double) {
        guard hasValue else {
            heldX = x
            heldY = y
            hasValue = true
            lastMoveTime = time
            return (x, y)
        }
        if isMoving && time - lastMoveTime > settleTime { isMoving = false }
        let width = isMoving ? movingWidth : max(startWidth, movingWidth)
        let dx = x - heldX, dy = y - heldY
        let distance = (dx * dx + dy * dy).squareRoot()
        if distance > width {
            let k = (distance - width) / distance
            heldX += dx * k
            heldY += dy * k
            isMoving = true
            lastMoveTime = time
        }
        return (heldX, heldY)
    }
}

/// Precision damping: slow head movement moves the pointer by only `gain` × the head
/// movement (fine control); deliberate movement gets full travel. The two regimes blend
/// smoothly around `precisionSpeed`. During deliberate movement the accumulated offset is
/// recovered so absolute pointing (look at a corner → reach the corner) is restored.
public struct PrecisionDamper: Sendable {
    /// Radians per second.
    public var precisionSpeed: Double
    public var gain: Double
    public var recoveryRate: Double

    /// Smoothed input speed in radians per second.
    public private(set) var speed: Double = 0
    private var lastX = 0.0, lastY = 0.0
    private var lastTime: TimeInterval?
    private var outX = 0.0, outY = 0.0

    public init(precisionSpeed: Double, gain: Double, recoveryRate: Double) {
        self.precisionSpeed = precisionSpeed
        self.gain = gain
        self.recoveryRate = recoveryRate
    }

    public mutating func reset() {
        lastTime = nil
        speed = 0
    }

    public mutating func apply(x: Double, y: Double, time: TimeInterval) -> (x: Double, y: Double) {
        guard let previous = lastTime else {
            lastX = x
            lastY = y
            outX = x
            outY = y
            lastTime = time
            return (x, y)
        }
        let dt = time - previous
        guard dt > 0 else { return (outX, outY) }
        let dx = x - lastX, dy = y - lastY
        speed += ((dx * dx + dy * dy).squareRoot() / dt - speed) * 0.5

        let blend = Self.smoothstep((speed - 0.5 * precisionSpeed) / max(precisionSpeed, 1e-9))
        let g = gain + (1 - gain) * blend
        outX += dx * g
        outY += dy * g
        let decay = exp(-recoveryRate * blend * dt)
        outX = x + (outX - x) * decay
        outY = y + (outY - y) * decay

        lastX = x
        lastY = y
        lastTime = time
        return (outX, outY)
    }

    /// 0 at u ≤ 0, 1 at u ≥ 1, eased in between.
    static func smoothstep(_ u: Double) -> Double {
        let t = min(max(u, 0), 1)
        return t * t * (3 - 2 * t)
    }
}
