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

/// Maps a (filtered) head pose to a normalized screen position using absolute pointing:
/// the neutral pose is the center and each calibrated range reaches its screen edge.
/// Roll is ignored.
public struct PointerMapper: Sendable {
    public var calibration: Calibration
    /// >1 means less head movement is needed to reach the edges.
    public var sensitivity: Double
    /// Backlash width in radians: the output only moves once the head has moved this far,
    /// which holds the cursor still against tiny tremors without stepping during slow moves.
    public var deadZone: Double

    private var heldYaw: Double?
    private var heldPitch: Double?

    public init(calibration: Calibration, sensitivity: Double, deadZoneDegrees: Double) {
        self.calibration = calibration
        self.sensitivity = sensitivity
        self.deadZone = AngleMath.radians(deadZoneDegrees)
    }

    /// Forget the dead-zone state, e.g. after recentering.
    public mutating func reset() {
        heldYaw = nil
        heldPitch = nil
    }

    public mutating func map(_ pose: HeadPose) -> NormalizedPoint {
        let relYaw = Self.backlash(AngleMath.wrap(pose.yaw - calibration.neutralYaw), held: &heldYaw, width: deadZone)
        let relPitch = Self.backlash(pose.pitch - calibration.neutralPitch, held: &heldPitch, width: deadZone)
        let gain = max(sensitivity, 0.05)

        let xRange = relYaw >= 0 ? calibration.rangeRight : calibration.rangeLeft
        let yRange = relPitch >= 0 ? calibration.rangeUp : calibration.rangeDown
        let x = 0.5 + 0.5 * relYaw * gain / max(xRange, 1e-6)
        // Looking up (positive pitch) moves toward y = 0 (top).
        let y = 0.5 - 0.5 * relPitch * gain / max(yRange, 1e-6)
        return NormalizedPoint(x: min(max(x, 0), 1), y: min(max(y, 0), 1))
    }

    private static func backlash(_ value: Double, held: inout Double?, width: Double) -> Double {
        guard let current = held else {
            held = value
            return value
        }
        let delta = value - current
        if abs(delta) > width {
            held = value - (delta > 0 ? width : -width)
        }
        return held ?? value
    }
}
