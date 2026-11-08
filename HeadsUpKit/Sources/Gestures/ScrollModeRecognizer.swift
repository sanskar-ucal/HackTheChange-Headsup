import Foundation

/// In-place scroll mode (entered with a double nod): head pitch relative to a neutral pose
/// sets the scroll velocity. Up = reveal content above, down = below. A neutral zone keeps
/// small movements from scrolling; speed eases in with angle.
///
/// The neutral pose is captured `settleTime` after entering, not at the double nod itself,
/// because the head is still mid-nod when the gesture is recognized.
public struct ScrollModeRecognizer: Sendable {
    /// Radians; nil until captured.
    public private(set) var entryPitch: Double?
    public var neutralDegrees: Double
    public var rampDegrees: Double
    public var maxSpeed: Double
    public var settleTime: TimeInterval
    private var settleUntil: TimeInterval?

    public init(settings: HeadsUpSettings, entryPitch: Double? = nil) {
        self.entryPitch = entryPitch
        neutralDegrees = settings.scrollModeNeutralDegrees
        rampDegrees = settings.scrollModeRampDegrees
        maxSpeed = settings.scrollMaxSpeed * settings.scrollSpeed
        settleTime = settings.scrollModeSettleTime
    }

    /// Points per second; positive reveals content above. Feed filtered poses.
    public mutating func velocity(for pose: HeadPose) -> ScrollVelocity {
        guard let entry = entryPitch else {
            let until = settleUntil ?? pose.timestamp + settleTime
            settleUntil = until
            if pose.timestamp >= until { entryPitch = pose.pitch }
            return .zero
        }
        let relative = AngleMath.degrees(pose.pitch - entry)
        let speed = ScrollCurve.speed(beyond: abs(relative), deadZone: neutralDegrees,
                                      ramp: rampDegrees, maxSpeed: maxSpeed)
        return ScrollVelocity(vertical: relative >= 0 ? speed : -speed)
    }
}
