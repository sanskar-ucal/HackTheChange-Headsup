import Foundation

/// Angular velocity of the head, in radians per second, using HeadsUp's axis convention (see `HeadPose`).
public struct RotationRate: Sendable, Equatable, Codable {
    public var pitch: Double
    public var yaw: Double
    public var roll: Double

    public init(pitch: Double, yaw: Double, roll: Double) {
        self.pitch = pitch
        self.yaw = yaw
        self.roll = roll
    }

    public static let zero = RotationRate(pitch: 0, yaw: 0, roll: 0)
}

/// Unit quaternion describing the raw attitude reported by the sensor.
public struct Quaternion: Sendable, Equatable, Codable {
    public var x: Double
    public var y: Double
    public var z: Double
    public var w: Double

    public init(x: Double, y: Double, z: Double, w: Double) {
        self.x = x
        self.y = y
        self.z = z
        self.w = w
    }

    public static let identity = Quaternion(x: 0, y: 0, z: 0, w: 1)
}

/// One head-orientation sample.
public struct HeadPose: Sendable, Equatable {
    public var timestamp: TimeInterval
    public var yaw: Double
    public var pitch: Double
    public var roll: Double
    public var rotationRate: RotationRate
    public var quaternion: Quaternion

    public init(
        timestamp: TimeInterval,
        yaw: Double,
        pitch: Double,
        roll: Double,
        rotationRate: RotationRate = .zero,
        quaternion: Quaternion = .identity
    ) {
        self.timestamp = timestamp
        self.yaw = yaw
        self.pitch = pitch
        self.roll = roll
        self.rotationRate = rotationRate
        self.quaternion = quaternion
    }

    /// Flips axes whose sign the hardware reports opposite to the HeadsUp convention.
    public func adjusted(invertYaw: Bool, invertPitch: Bool, invertRoll: Bool) -> HeadPose {
        var pose = self
        if invertYaw {
            pose.yaw = -pose.yaw
            pose.rotationRate.yaw = -pose.rotationRate.yaw
        }
        if invertPitch {
            pose.pitch = -pose.pitch
            pose.rotationRate.pitch = -pose.rotationRate.pitch
        }
        if invertRoll {
            pose.roll = -pose.roll
            pose.rotationRate.roll = -pose.rotationRate.roll
        }
        return pose
    }
}

/// Small helpers for angle arithmetic.
public enum AngleMath {
    /// Wraps an angle into (-π, π].
    public static func wrap(_ angle: Double) -> Double {
        var a = angle.truncatingRemainder(dividingBy: 2 * .pi)
        if a > .pi { a -= 2 * .pi }
        if a <= -.pi { a += 2 * .pi }
        return a
    }

    public static func radians(_ degrees: Double) -> Double { degrees * .pi / 180 }
    public static func degrees(_ radians: Double) -> Double { radians * 180 / .pi }
}
