import Foundation

/// The head pose captured for one calibration target (radians).
public struct CapturedPose: Sendable, Equatable, Codable {
    public var yaw: Double
    public var pitch: Double
    public var roll: Double

    public init(yaw: Double, pitch: Double, roll: Double) {
        self.yaw = yaw
        self.pitch = pitch
        self.roll = roll
    }

    public init(_ pose: HeadPose) {
        self.init(yaw: pose.yaw, pitch: pose.pitch, roll: pose.roll)
    }
}

public enum CalibrationAxis: String, Sendable, Equatable {
    case left, right, up, down
}

public enum CalibrationError: Error, Sendable, Equatable {
    case missingCapture(CalibrationStep)
    case rangeTooSmall(CalibrationAxis, degrees: Double)
    /// The final center check differed from the first center capture.
    case centerDrifted(degrees: Double)

    public var userMessage: String {
        switch self {
        case .missingCapture:
            return "Calibration was interrupted. Let's start again."
        case let .rangeTooSmall(axis, degrees):
            let measured = String(format: "%.0f", degrees)
            return "Your head moved only \(measured) degrees toward the \(axis.rawValue). "
                + "Turn a little further toward each corner. Let's try again."
        case let .centerDrifted(degrees):
            let measured = String(format: "%.0f", degrees)
            return "Your center position moved \(measured) degrees during calibration. "
                + "Keep your body still. Let's try again."
        }
    }
}

/// Per-user mapping model: the neutral pose plus how far the head turns to reach each
/// screen edge. Each side is fitted independently because range of motion is often
/// asymmetric. All values are radians; ranges are positive.
public struct Calibration: Sendable, Equatable, Codable {
    public var neutralYaw: Double
    public var neutralPitch: Double
    public var neutralRoll: Double
    public var rangeLeft: Double
    public var rangeRight: Double
    public var rangeUp: Double
    public var rangeDown: Double

    public init(neutralYaw: Double, neutralPitch: Double, neutralRoll: Double,
                rangeLeft: Double, rangeRight: Double, rangeUp: Double, rangeDown: Double) {
        self.neutralYaw = neutralYaw
        self.neutralPitch = neutralPitch
        self.neutralRoll = neutralRoll
        self.rangeLeft = rangeLeft
        self.rangeRight = rangeRight
        self.rangeUp = rangeUp
        self.rangeDown = rangeDown
    }

    /// Fits a calibration from the five captured poses.
    ///
    /// Corner targets sit `targetInset` (normalized) in from the screen edges, so the
    /// measured angle is extrapolated to the full half-width:
    /// `range = |angle| × 0.5 / (0.5 − inset)`.
    public static func fit(
        captures: [CalibrationStep: CapturedPose],
        targetInset: Double,
        minRangeDegrees: Double
    ) throws -> Calibration {
        for step in CalibrationStep.fitSteps where captures[step] == nil {
            throw CalibrationError.missingCapture(step)
        }
        let neutral = captures[.center]!
        func relYaw(_ step: CalibrationStep) -> Double { AngleMath.wrap(captures[step]!.yaw - neutral.yaw) }
        func relPitch(_ step: CalibrationStep) -> Double { captures[step]!.pitch - neutral.pitch }

        let scale = 0.5 / max(0.5 - targetInset, 0.05)
        let left = -(relYaw(.topLeft) + relYaw(.bottomLeft)) / 2 * scale
        let right = (relYaw(.topRight) + relYaw(.bottomRight)) / 2 * scale
        let up = (relPitch(.topLeft) + relPitch(.topRight)) / 2 * scale
        let down = -(relPitch(.bottomLeft) + relPitch(.bottomRight)) / 2 * scale

        let minRange = AngleMath.radians(minRangeDegrees)
        let ranges: [(CalibrationAxis, Double)] = [(.left, left), (.right, right), (.up, up), (.down, down)]
        for (axis, range) in ranges where range < minRange {
            throw CalibrationError.rangeTooSmall(axis, degrees: AngleMath.degrees(range))
        }

        return Calibration(
            neutralYaw: neutral.yaw, neutralPitch: neutral.pitch, neutralRoll: neutral.roll,
            rangeLeft: left, rangeRight: right, rangeUp: up, rangeDown: down)
    }

    /// Keeps the fitted ranges but makes `pose` the new neutral (fixes yaw drift).
    public func recentered(to pose: CapturedPose) -> Calibration {
        var copy = self
        copy.neutralYaw = pose.yaw
        copy.neutralPitch = pose.pitch
        copy.neutralRoll = pose.roll
        return copy
    }
}
