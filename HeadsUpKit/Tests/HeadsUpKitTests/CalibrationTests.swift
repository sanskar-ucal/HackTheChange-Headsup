import XCTest
@testable import HeadsUpKit

final class CalibrationTests: XCTestCase {
    private let r = AngleMath.radians

    /// Corner poses for targets inset 5%: yaw ±18° and pitch ±13.5° → ±20° / ±15° ranges.
    private func captures(neutralYaw: Double = 0, leftScale: Double = 1) -> [CalibrationStep: CapturedPose] {
        [
            .center: CapturedPose(yaw: r(neutralYaw), pitch: 0, roll: r(2)),
            .topLeft: CapturedPose(yaw: r(neutralYaw - 18 * leftScale), pitch: r(13.5), roll: 0),
            .topRight: CapturedPose(yaw: r(neutralYaw + 18), pitch: r(13.5), roll: 0),
            .bottomRight: CapturedPose(yaw: r(neutralYaw + 18), pitch: r(-13.5), roll: 0),
            .bottomLeft: CapturedPose(yaw: r(neutralYaw - 18 * leftScale), pitch: r(-13.5), roll: 0),
        ]
    }

    func testFitExtrapolatesInsetTargetsToEdges() throws {
        let calibration = try Calibration.fit(captures: captures(), targetInset: 0.05, minRangeDegrees: 5)
        XCTAssertEqual(AngleMath.degrees(calibration.rangeLeft), 20, accuracy: 1e-6)
        XCTAssertEqual(AngleMath.degrees(calibration.rangeRight), 20, accuracy: 1e-6)
        XCTAssertEqual(AngleMath.degrees(calibration.rangeUp), 15, accuracy: 1e-6)
        XCTAssertEqual(AngleMath.degrees(calibration.rangeDown), 15, accuracy: 1e-6)
        XCTAssertEqual(AngleMath.degrees(calibration.neutralRoll), 2, accuracy: 1e-6)
    }

    func testFitsSidesIndependently() throws {
        let calibration = try Calibration.fit(
            captures: captures(leftScale: 0.5), targetInset: 0.05, minRangeDegrees: 5)
        XCTAssertEqual(AngleMath.degrees(calibration.rangeLeft), 10, accuracy: 1e-6)
        XCTAssertEqual(AngleMath.degrees(calibration.rangeRight), 20, accuracy: 1e-6)
    }

    func testFitHandlesNeutralNearYawSeam() throws {
        let calibration = try Calibration.fit(
            captures: captures(neutralYaw: 175), targetInset: 0.05, minRangeDegrees: 5)
        XCTAssertEqual(AngleMath.degrees(calibration.rangeRight), 20, accuracy: 1e-6)
        XCTAssertEqual(AngleMath.degrees(calibration.rangeLeft), 20, accuracy: 1e-6)
    }

    func testRejectsTooSmallRange() {
        XCTAssertThrowsError(try Calibration.fit(
            captures: captures(leftScale: 0.1), targetInset: 0.05, minRangeDegrees: 5)
        ) { error in
            guard case let CalibrationError.rangeTooSmall(axis, degrees) = error else {
                return XCTFail("unexpected error \(error)")
            }
            XCTAssertEqual(axis, .left)
            XCTAssertEqual(degrees, 2, accuracy: 1e-6)
        }
    }

    func testRejectsMissingCapture() {
        var partial = captures()
        partial[.bottomLeft] = nil
        XCTAssertThrowsError(try Calibration.fit(captures: partial, targetInset: 0.05, minRangeDegrees: 5))
    }

    func testRecenterKeepsRanges() throws {
        let calibration = try Calibration.fit(captures: captures(), targetInset: 0.05, minRangeDegrees: 5)
        let recentered = calibration.recentered(to: CapturedPose(yaw: r(40), pitch: r(-3), roll: r(1)))
        XCTAssertEqual(recentered.neutralYaw, r(40))
        XCTAssertEqual(recentered.neutralPitch, r(-3))
        XCTAssertEqual(recentered.rangeLeft, calibration.rangeLeft)
        XCTAssertEqual(recentered.rangeDown, calibration.rangeDown)
    }

    func testSessionCapturesAllTargetsByDwell() {
        var session = CalibrationSession(settings: .defaults)
        let targets: [(Double, Double)] = [(0, 0), (-18, 13.5), (18, 13.5), (18, -13.5), (-18, -13.5)]
        var captured: [CalibrationStep] = []
        var result: Calibration?
        var t = 0.0
        for (yaw, pitch) in targets {
            for _ in 0..<50 {  // 2 s per target at 25 Hz
                let pose = HeadPose(timestamp: t, yaw: r(yaw), pitch: r(pitch), roll: 0)
                t += 0.04
                switch session.process(pose) {
                case let .captured(step, _): captured.append(step)
                case let .finished(calibration): result = calibration
                case .failed(let error): XCTFail("calibration failed: \(error)")
                case .progress: break
                }
            }
        }
        XCTAssertEqual(captured, [.center, .topLeft, .topRight, .bottomRight])
        XCTAssertEqual(AngleMath.degrees(result?.rangeRight ?? 0), 20, accuracy: 1e-6)
    }

    func testSessionDoesNotCaptureNextTargetWithoutMoving() {
        var session = CalibrationSession(settings: .defaults)
        var captures = 0
        for i in 0..<150 {  // 6 s staring at the center
            let pose = HeadPose(timestamp: Double(i) * 0.04, yaw: 0, pitch: 0, roll: 0)
            if case .captured = session.process(pose) { captures += 1 }
        }
        XCTAssertEqual(captures, 1, "only the center target is captured")
        XCTAssertEqual(session.step, .topLeft)
    }

    @MainActor
    func testCalibrationStoreRoundTrip() throws {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: "HeadsUpTests.\(UUID().uuidString)"))
        let calibration = try Calibration.fit(captures: captures(), targetInset: 0.05, minRangeDegrees: 5)
        let store = UserDefaultsCalibrationStore(defaults: defaults)
        XCTAssertNil(store.load())
        store.save(calibration)
        XCTAssertEqual(store.load(), calibration)
        store.clear()
        XCTAssertNil(store.load())
    }
}
