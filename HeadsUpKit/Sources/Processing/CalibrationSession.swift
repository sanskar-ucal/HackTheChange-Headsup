import Foundation

/// Hands-free calibration (the v1 flow): center, then the four corners, each captured when
/// the head has dwelled still on it, then the center again as a drift check.
///
/// Feed it **raw** sensor poses: calibration must not depend on smoothing, sensitivity,
/// snapping or the pointer spring. Each capture is the median pose over the last
/// `captureWindow` of the dwell, and is only accepted if the head turned slower than
/// `maxCaptureRate` throughout that window.
public struct CalibrationSession: Sendable {
    public enum Update: Sendable, Equatable {
        /// Dwell progress (0…1) on the current step.
        case progress(Double)
        /// `step` was captured; the user should now look at `next`.
        case captured(CalibrationStep, next: CalibrationStep)
        /// The dwell completed but the head wasn't still enough; the dwell restarts.
        case rejected(CalibrationStep)
        case finished(Calibration)
        case failed(CalibrationError)
    }

    public private(set) var step: CalibrationStep = .center
    private var captures: [CalibrationStep: CapturedPose] = [:]
    private var dwell: StillnessDetector
    private var window: [HeadPose] = []
    private var lastCapture: CapturedPose?
    private let minMove: Double
    private let targetInset: Double
    private let minRangeDegrees: Double
    private let captureWindow: TimeInterval
    /// Radians per second.
    private let maxCaptureRate: Double
    private let centerDriftDegrees: Double

    public init(settings: HeadsUpSettings) {
        dwell = StillnessDetector(
            toleranceDegrees: settings.calibrationDwellToleranceDegrees,
            duration: settings.calibrationDwellDuration)
        minMove = AngleMath.radians(settings.calibrationMinMoveDegrees)
        targetInset = settings.calibrationTargetInset
        minRangeDegrees = settings.calibrationMinRangeDegrees
        captureWindow = min(settings.calibrationCaptureWindow, settings.calibrationDwellDuration)
        maxCaptureRate = AngleMath.radians(settings.calibrationMaxCaptureRateDegPerSec)
        centerDriftDegrees = settings.calibrationCenterDriftDegrees
    }

    public mutating func process(_ pose: HeadPose) -> Update {
        // Don't let a dwell count until the head has actually moved toward the new target.
        if let last = lastCapture {
            let moved = max(abs(AngleMath.wrap(pose.yaw - last.yaw)), abs(pose.pitch - last.pitch))
            if moved < minMove {
                restartDwell()
                return .progress(0)
            }
        }

        window.append(pose)
        window.removeAll { pose.timestamp - $0.timestamp > captureWindow }
        let progress = dwell.update(pose)
        guard progress >= 1 else { return .progress(progress) }

        let fastest = window.map { hypot($0.rotationRate.yaw, $0.rotationRate.pitch) }.max() ?? .infinity
        guard fastest < maxCaptureRate else {
            restartDwell()
            return .rejected(step)
        }

        let captured = Self.median(of: window)
        restartDwell()

        if step == .centerCheck {
            return finish(recheckedCenter: captured)
        }
        captures[step] = captured
        lastCapture = captured
        guard let next = step.next else { return finish(recheckedCenter: nil) }
        let done = step
        step = next
        return .captured(done, next: next)
    }

    private mutating func restartDwell() {
        dwell.reset()
        window.removeAll()
    }

    private func finish(recheckedCenter: CapturedPose?) -> Update {
        if let recheck = recheckedCenter, let first = captures[.center] {
            let drift = AngleMath.degrees(max(abs(AngleMath.wrap(recheck.yaw - first.yaw)),
                                              abs(recheck.pitch - first.pitch)))
            if drift > centerDriftDegrees { return .failed(.centerDrifted(degrees: drift)) }
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

    /// Per-axis median; yaw is taken relative to the first sample so ±π wrap is safe.
    static func median(of poses: [HeadPose]) -> CapturedPose {
        guard let base = poses.first else { return CapturedPose(yaw: 0, pitch: 0, roll: 0) }
        func median(_ values: [Double]) -> Double {
            let sorted = values.sorted()
            let mid = sorted.count / 2
            return sorted.count % 2 == 0 ? (sorted[mid - 1] + sorted[mid]) / 2 : sorted[mid]
        }
        let yaw = median(poses.map { AngleMath.wrap($0.yaw - base.yaw) })
        return CapturedPose(yaw: AngleMath.wrap(base.yaw + yaw),
                            pitch: median(poses.map(\.pitch)),
                            roll: median(poses.map(\.roll)))
    }
}
