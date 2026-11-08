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

/// How far (degrees) the head points beyond each screen edge.
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

/// Mapped pointer position plus how far the head is past each screen edge.
public struct MappedPointer: Sendable, Equatable {
    /// Clamped to the screen.
    public var point: NormalizedPoint
    public var overshoot: EdgeOvershoot
}

/// Maps a (One Euro filtered) head pose to a normalized screen position.
public struct PointerMapper: Sendable {
    public struct Config: Sendable, Equatable {
        /// Pure scale on the mapping: 1 maps the calibrated corners to the screen corners.
        public var sensitivity: Double

        public init(sensitivity: Double = 1) {
            self.sensitivity = sensitivity
        }

        public init(settings: HeadsUpSettings) {
            self.init(sensitivity: settings.sensitivity)
        }
    }

    public var calibration: Calibration
    /// Changing the config (e.g. sensitivity) takes effect immediately; no recalibration.
    public var config: Config

    public init(calibration: Calibration, config: Config) {
        self.calibration = calibration
        self.config = config
    }

    public func map(_ pose: HeadPose) -> MappedPointer {
        Self.map(yaw: AngleMath.wrap(pose.yaw - calibration.neutralYaw),
                 pitch: pose.pitch - calibration.neutralPitch,
                 calibration: calibration, sensitivity: config.sensitivity)
    }

    /// The pure mapping from angles relative to neutral (radians).
    public static func map(yaw: Double, pitch: Double, calibration: Calibration, sensitivity: Double) -> MappedPointer {
        let gain = max(sensitivity, 0.05)
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
        return MappedPointer(point: NormalizedPoint(x: min(max(x, 0), 1), y: min(max(y, 0), 1)), overshoot: overshoot)
    }
}
