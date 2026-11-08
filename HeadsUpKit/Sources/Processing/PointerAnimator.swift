import CoreGraphics
import Foundation

/// Display-rate pointer motion: a critically damped spring chases the target, removing the
/// stepping of 25–50 Hz sensor updates. Glides (eased tweens) replace the spring for
/// releases after a nod, resume and recenter so nothing teleports.
public struct PointerAnimator: Sendable {
    public struct Step: Sendable, Equatable {
        public var position: CGPoint
        /// Token of a glide that finished on this step.
        public var finishedGlide: Int?
    }

    /// ω² of the spring. Critically damped settle (2 %) takes ≈ 5.8 / √stiffness seconds
    /// (≈ 39 ms at the default 22000).
    public var stiffness: Double
    public private(set) var position: CGPoint?
    private var velocityX = 0.0
    private var velocityY = 0.0
    private var glide: Glide?

    private struct Glide: Sendable {
        var from: CGPoint?
        var to: CGPoint
        var duration: TimeInterval
        var start: TimeInterval?
        var token: Int
    }

    public init(stiffness: Double) {
        self.stiffness = stiffness
    }

    public var isGliding: Bool { glide != nil }

    /// Jumps without animation (used to sync with the real cursor).
    public mutating func place(at point: CGPoint) {
        position = point
        velocityX = 0
        velocityY = 0
        glide = nil
    }

    /// Eases from the current position to `point`; the spring resumes afterwards.
    public mutating func glide(to point: CGPoint, duration: TimeInterval, token: Int = 0) {
        glide = Glide(from: nil, to: point, duration: max(duration, 0), start: nil, token: token)
    }

    /// 0 at u ≤ 0, 1 at u ≥ 1, eased in between.
    static func smoothstep(_ u: Double) -> Double {
        let t = min(max(u, 0), 1)
        return t * t * (3 - 2 * t)
    }

    public mutating func step(toward target: CGPoint, now: TimeInterval, dt rawDt: Double) -> Step {
        guard let current = position else {
            position = glide?.to ?? target
            let token = glide?.token
            glide = nil
            return Step(position: position ?? target, finishedGlide: token)
        }

        if var active = glide {
            let start = active.start ?? now
            let from = active.from ?? current
            active.start = start
            active.from = from
            let fraction = active.duration > 0 ? (now - start) / active.duration : 1
            if fraction >= 1 {
                place(at: active.to)
                return Step(position: active.to, finishedGlide: active.token)
            }
            glide = active
            let e = Self.smoothstep(fraction)
            let point = CGPoint(x: from.x + (active.to.x - from.x) * e, y: from.y + (active.to.y - from.y) * e)
            position = point
            return Step(position: point, finishedGlide: nil)
        }

        let dt = min(max(rawDt, 0), 0.05)
        let omega = max(stiffness, 1).squareRoot()
        let decay = exp(-omega * dt)
        func spring(_ x: Double, _ v: Double, _ goal: Double) -> (Double, Double) {
            let x0 = x - goal
            let k = v + omega * x0
            return (goal + (x0 + k * dt) * decay, (v - omega * k * dt) * decay)
        }
        let (x, vx) = spring(current.x, velocityX, target.x)
        let (y, vy) = spring(current.y, velocityY, target.y)
        velocityX = vx
        velocityY = vy
        let point = CGPoint(x: x, y: y)
        position = point
        return Step(position: point, finishedGlide: nil)
    }
}
