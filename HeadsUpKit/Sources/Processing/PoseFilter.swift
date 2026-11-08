import Foundation

/// Smooths yaw, pitch and roll with one `OneEuroFilter` per axis.
///
/// Signals are filtered in degrees, so the default `beta` is in units of 1/(°/s). Yaw is
/// unwrapped before filtering so crossing ±π doesn't produce a 360° jump. Rotation rates
/// pass through untouched (gesture recognizers need the raw gyro response).
public struct PoseFilter: Sendable {
    private var yawFilter: OneEuroFilter
    private var pitchFilter: OneEuroFilter
    private var rollFilter: OneEuroFilter
    private var lastRawYaw: Double?
    private var unwrappedYaw: Double = 0

    public init(minCutoff: Double, beta: Double, dCutoff: Double) {
        let filter = OneEuroFilter(minCutoff: minCutoff, beta: beta, dCutoff: dCutoff)
        yawFilter = filter
        pitchFilter = filter
        rollFilter = filter
    }

    public init(settings: HeadsUpSettings) {
        self.init(minCutoff: settings.filterMinCutoff, beta: settings.filterBeta, dCutoff: settings.filterDCutoff)
    }

    public mutating func configure(minCutoff: Double, beta: Double, dCutoff: Double) {
        for keyPath in [\PoseFilter.yawFilter, \PoseFilter.pitchFilter, \PoseFilter.rollFilter] {
            self[keyPath: keyPath].minCutoff = minCutoff
            self[keyPath: keyPath].beta = beta
            self[keyPath: keyPath].dCutoff = dCutoff
        }
    }

    public mutating func reset() {
        yawFilter.reset()
        pitchFilter.reset()
        rollFilter.reset()
        lastRawYaw = nil
        unwrappedYaw = 0
    }

    public mutating func filter(_ pose: HeadPose) -> HeadPose {
        if let lastRawYaw {
            unwrappedYaw += AngleMath.wrap(pose.yaw - lastRawYaw)
        } else {
            unwrappedYaw = pose.yaw
        }
        lastRawYaw = pose.yaw

        let t = pose.timestamp
        var result = pose
        result.yaw = AngleMath.wrap(AngleMath.radians(yawFilter.filter(AngleMath.degrees(unwrappedYaw), at: t)))
        result.pitch = AngleMath.radians(pitchFilter.filter(AngleMath.degrees(pose.pitch), at: t))
        result.roll = AngleMath.radians(rollFilter.filter(AngleMath.degrees(pose.roll), at: t))
        return result
    }
}
