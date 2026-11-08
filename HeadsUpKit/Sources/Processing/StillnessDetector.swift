import Foundation

/// Reports how long the head has stayed within a tolerance of an anchor pose.
public struct StillnessDetector: Sendable {
    /// Radians.
    public var tolerance: Double
    public var duration: TimeInterval

    private var anchor: HeadPose?

    public init(toleranceDegrees: Double, duration: TimeInterval) {
        self.tolerance = AngleMath.radians(toleranceDegrees)
        self.duration = duration
    }

    public mutating func reset() {
        anchor = nil
    }

    /// Returns progress 0…1; 1 means the head has been still for `duration`.
    public mutating func update(_ pose: HeadPose) -> Double {
        guard let start = anchor else {
            anchor = pose
            return 0
        }
        let yawDelta = abs(AngleMath.wrap(pose.yaw - start.yaw))
        let pitchDelta = abs(pose.pitch - start.pitch)
        if max(yawDelta, pitchDelta) > tolerance {
            anchor = pose
            return 0
        }
        guard duration > 0 else { return 1 }
        return min((pose.timestamp - start.timestamp) / duration, 1)
    }
}
