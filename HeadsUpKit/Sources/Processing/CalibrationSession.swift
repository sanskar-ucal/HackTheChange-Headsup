import Foundation

/// Hands-free calibration: walks through the five targets, capturing each one when the
/// head has dwelled still on it, then fits a `Calibration`.
public struct CalibrationSession: Sendable {
    public enum Update: Sendable, Equatable {
        /// Dwell progress (0…1) on the current step.
        case progress(Double)
        /// `step` was captured; the user should now look at `next`.
        case captured(CalibrationStep, next: CalibrationStep)
        case finished(Calibration)
        case failed(CalibrationError)
    }

    public private(set) var step: CalibrationStep = .center
    private var captures: [CalibrationStep: CapturedPose] = [:]
    private var dwell: StillnessDetector
    private var lastCapture: CapturedPose?
    private let minMove: Double
    private let targetInset: Double
    private let minRangeDegrees: Double

    public init(settings: Settings) {
        dwell = StillnessDetector(
            toleranceDegrees: settings.calibrationDwellToleranceDegrees,
            duration: settings.calibrationDwellDuration)
        minMove = AngleMath.radians(settings.calibrationMinMoveDegrees)
        targetInset = settings.calibrationTargetInset
        minRangeDegrees = settings.calibrationMinRangeDegrees
    }

    /// Feed filtered poses.
    public mutating func process(_ pose: HeadPose) -> Update {
        // Don't let a dwell count until the head has actually moved toward the new target.
        if let last = lastCapture {
            let moved = max(abs(AngleMath.wrap(pose.yaw - last.yaw)), abs(pose.pitch - last.pitch))
            if moved < minMove {
                dwell.reset()
                return .progress(0)
            }
        }

        let progress = dwell.update(pose)
        guard progress >= 1 else { return .progress(progress) }

        let captured = CapturedPose(pose)
        captures[step] = captured
        lastCapture = captured
        dwell.reset()

        if let next = step.next {
            let done = step
            step = next
            return .captured(done, next: next)
        }
        do {
            return .finished(try Calibration.fit(
                captures: captures, targetInset: targetInset, minRangeDegrees: minRangeDegrees))
        } catch let error as CalibrationError {
            return .failed(error)
        } catch {
            return .failed(.missingCapture(step))
        }
    }
}
