import Foundation

/// A point in 0…1 space with a top-left origin.
public struct NormalizedPoint: Sendable, Equatable {
    public var x: Double
    public var y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }

    public static let center = NormalizedPoint(x: 0.5, y: 0.5)
}

/// How far (degrees) the head points beyond each screen edge. Drives edge-push scrolling.
public struct EdgeOvershoot: Sendable, Equatable {
    public var up = 0.0, down = 0.0, left = 0.0, right = 0.0

    public init(up: Double = 0, down: Double = 0, left: Double = 0, right: Double = 0) {
        self.up = up
        self.down = down
        self.left = left
        self.right = right
    }

    public static let zero = EdgeOvershoot()
}

public struct MappedPointer: Sendable, Equatable {
    /// Clamped to the screen.
    public var point: NormalizedPoint
    public var overshoot: EdgeOvershoot
    /// Smoothed head angular speed, degrees per second.
    public var headSpeed: Double
}

/// Maps a (filtered) head pose to a normalized screen position.
///
/// Stages: angle relative to neutral → hysteretic dead zone → precision damping →
/// linear mapping with `sensitivity` against the calibrated per-side ranges. Roll is ignored.
public struct PointerMapper: Sendable {
    public struct Config: Sendable, Equatable {
        public var sensitivity: Double
        public var deadZoneDegrees: Double
        public var deadZoneStartDegrees: Double
        public var settleTime: TimeInterval
        public var precisionSpeedDegPerSec: Double
        public var precisionGain: Double
        public var precisionRecoveryPerSec: Double

        public init(sensitivity: Double = 1, deadZoneDegrees: Double = 0, deadZoneStartDegrees: Double = 0,
                    settleTime: TimeInterval = 0.25, precisionSpeedDegPerSec: Double = 15,
                    precisionGain: Double = 1, precisionRecoveryPerSec: Double = 3) {
            self.sensitivity = sensitivity
            self.deadZoneDegrees = deadZoneDegrees
            self.deadZoneStartDegrees = deadZoneStartDegrees
            self.settleTime = settleTime
            self.precisionSpeedDegPerSec = precisionSpeedDegPerSec
            self.precisionGain = precisionGain
            self.precisionRecoveryPerSec = precisionRecoveryPerSec
        }

        public init(settings: HeadsUpSettings) {
            self.init(sensitivity: settings.sensitivity, deadZoneDegrees: settings.deadZoneDegrees,
                      deadZoneStartDegrees: settings.deadZoneStartDegrees, settleTime: settings.deadZoneSettleTime,
                      precisionSpeedDegPerSec: settings.precisionSpeedDegPerSec, precisionGain: settings.precisionGain,
                      precisionRecoveryPerSec: settings.precisionRecoveryPerSec)
        }
    }

    public var calibration: Calibration
    /// Changing the config (e.g. sensitivity) takes effect immediately; no recalibration.
    public var config: Config {
        didSet { configureStages() }
    }

    private var deadband: HysteresisDeadband
    private var damper: PrecisionDamper

    public init(calibration: Calibration, config: Config) {
        self.calibration = calibration
        self.config = config
        deadband = HysteresisDeadband(movingWidth: 0, startWidth: 0, settleTime: 0)
        damper = PrecisionDamper(precisionSpeed: 0, gain: 1, recoveryRate: 0)
        configureStages()
    }

    /// Forget dead-zone and damping state, e.g. after recentering.
    public mutating func reset() {
        deadband.reset()
        damper.reset()
    }

    public mutating func map(_ pose: HeadPose) -> MappedPointer {
        let relYaw = AngleMath.wrap(pose.yaw - calibration.neutralYaw)
        let relPitch = pose.pitch - calibration.neutralPitch
        let held = deadband.apply(x: relYaw, y: relPitch, time: pose.timestamp)
        let (yaw, pitch) = damper.apply(x: held.x, y: held.y, time: pose.timestamp)

        let gain = max(config.sensitivity, 0.05)
        let xRange = max(yaw >= 0 ? calibration.rangeRight : calibration.rangeLeft, 1e-6)
        let yRange = max(pitch >= 0 ? calibration.rangeUp : calibration.rangeDown, 1e-6)
        let x = 0.5 + 0.5 * yaw * gain / xRange
        // Looking up (positive pitch) moves toward y = 0 (top).
        let y = 0.5 - 0.5 * pitch * gain / yRange

        let beyond = { (angle: Double, edge: Double) in AngleMath.degrees(max(0, angle - edge)) }
        let overshoot = EdgeOvershoot(
            up: beyond(pitch, calibration.rangeUp / gain),
            down: beyond(-pitch, calibration.rangeDown / gain),
            left: beyond(-yaw, calibration.rangeLeft / gain),
            right: beyond(yaw, calibration.rangeRight / gain))
        return MappedPointer(
            point: NormalizedPoint(x: min(max(x, 0), 1), y: min(max(y, 0), 1)),
            overshoot: overshoot,
            headSpeed: AngleMath.degrees(damper.speed))
    }

    private mutating func configureStages() {
        deadband.movingWidth = AngleMath.radians(config.deadZoneDegrees)
        deadband.startWidth = AngleMath.radians(config.deadZoneStartDegrees)
        deadband.settleTime = config.settleTime
        damper.precisionSpeed = AngleMath.radians(config.precisionSpeedDegPerSec)
        damper.gain = min(max(config.precisionGain, 0.05), 1)
        damper.recoveryRate = config.precisionRecoveryPerSec
    }
}
