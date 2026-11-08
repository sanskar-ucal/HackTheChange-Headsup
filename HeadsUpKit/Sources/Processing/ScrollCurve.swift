import Foundation

/// Maps "how far past the neutral zone" to a scroll speed with an ease-in curve.
public enum ScrollCurve {
<<<<<<< HEAD
    /// - Parameters:
    ///   - angle: degrees past the reference (edge or scroll-mode entry pose), ≥ 0.
    ///   - deadZone: degrees that produce no scrolling.
    ///   - ramp: degrees beyond the dead zone at which `maxSpeed` is reached.
    ///   - minFraction: share of `maxSpeed` applied the moment the dead zone is passed, so
    ///     engaging is immediately noticeable instead of starting at ~0.
    /// - Returns: points per second, 0…maxSpeed.
    public static func speed(beyond angle: Double, deadZone: Double, ramp: Double, maxSpeed: Double,
                             minFraction: Double = 0) -> Double {
        guard angle > deadZone else { return 0 }
        let x = min((angle - deadZone) / max(ramp, 1e-6), 1)
        let floor = min(max(minFraction, 0), 1)
        return maxSpeed * (floor + (1 - floor) * x * x)
=======
    /// - Parameters: - angle: degrees past the reference (edge or scroll-mode entry pose), ≥ 0. - deadZone.
    public static func speed(beyond angle: Double, deadZone: Double, ramp: Double, maxSpeed: Double) -> Double {
        let x = min(max((angle - deadZone) / max(ramp, 1e-6), 0), 1)
        return maxSpeed * x * x
>>>>>>> cdc6d7146c27e1e0f65617d4b343c4e907f2d9cb
    }
}

/// Scroll velocity in points per second.
public struct ScrollVelocity: Sendable, Equatable {
    public var vertical: Double
    public var horizontal: Double

    public init(vertical: Double = 0, horizontal: Double = 0) {
        self.vertical = vertical
        self.horizontal = horizontal
    }

    public static let zero = ScrollVelocity()
    public var isZero: Bool { vertical == 0 && horizontal == 0 }

    /// Edge-push scrolling from the mapper's overshoot.
    public static func edgePush(_ overshoot: EdgeOvershoot, settings: HeadsUpSettings) -> ScrollVelocity {
        guard settings.edgeScrollEnabled else { return .zero }
        let maxSpeed = settings.scrollMaxSpeed * settings.scrollSpeed
        func speed(_ angle: Double) -> Double {
            ScrollCurve.speed(beyond: angle, deadZone: settings.scrollEngageOvershootDegrees,
                              ramp: settings.scrollRampDegrees, maxSpeed: maxSpeed,
                              minFraction: settings.scrollEngageMinFraction)
        }
        var velocity = ScrollVelocity(vertical: speed(overshoot.up) - speed(overshoot.down))
        if settings.horizontalEdgeScroll {
            velocity.horizontal = speed(overshoot.left) - speed(overshoot.right)
        }
        return velocity
    }
}
