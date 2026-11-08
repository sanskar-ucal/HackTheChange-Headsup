import Foundation

/// Tilt-hold thresholds, in radians and seconds.
public struct TiltHoldConfig: Sendable, Equatable {
    /// Radians.
    public var threshold: Double
    public var holdDuration: TimeInterval
    public var releaseFraction: Double

    public init(settings: HeadsUpSettings) {
        threshold = AngleMath.radians(settings.tiltThresholdDegrees)
        holdDuration = settings.tiltHoldDuration
        releaseFraction = settings.tiltReleaseFraction
    }
}

/// Fires `tiltHoldLeft` / `tiltHoldRight` when roll stays past the threshold for the hold duration.
public struct TiltHoldRecognizer: GestureRecognizer {
    public var config: TiltHoldConfig
    /// Roll of the neutral pose (radians); tilt is measured relative to it.
    public var rollReference: Double = 0

    private var holdGesture: HeadGesture?
    private var holdStart: TimeInterval = 0
    private var awaitingRelease = false

    public init(config: TiltHoldConfig) {
        self.config = config
    }

    public mutating func reset() {
        holdGesture = nil
        awaitingRelease = false
    }

    public mutating func process(_ pose: HeadPose) -> [GestureEvent] {
        let roll = AngleMath.wrap(pose.roll - rollReference)
        if awaitingRelease {
            if abs(roll) < config.threshold * config.releaseFraction { awaitingRelease = false }
            return []
        }

        let tilted: HeadGesture?
        if roll <= -config.threshold {
            tilted = .tiltHoldLeft
        } else if roll >= config.threshold {
            tilted = .tiltHoldRight
        } else {
            tilted = nil
        }

        guard let tilted else {
            guard let previous = holdGesture else { return [] }
            holdGesture = nil
            return [.holdCancelled(previous)]
        }

        guard holdGesture == tilted else {
            var events: [GestureEvent] = []
            if let previous = holdGesture { events.append(.holdCancelled(previous)) }
            holdGesture = tilted
            holdStart = pose.timestamp
            events.append(.holdProgress(tilted, fraction: 0))
            return events
        }

        let fraction = config.holdDuration > 0 ? (pose.timestamp - holdStart) / config.holdDuration : 1
        if fraction >= 1 {
            holdGesture = nil
            awaitingRelease = true
            return [.confirmed(tilted, onset: holdStart)]
        }
        return [.holdProgress(tilted, fraction: fraction)]
    }
}
