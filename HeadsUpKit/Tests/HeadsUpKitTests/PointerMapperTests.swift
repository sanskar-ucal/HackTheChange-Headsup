import XCTest
@testable import HeadsUpKit

final class PointerMapperTests: XCTestCase {
    private let r = AngleMath.radians

    private func calibration(neutralYaw: Double = 0) -> Calibration {
        Calibration(neutralYaw: neutralYaw, neutralPitch: 0, neutralRoll: 0,
                    rangeLeft: r(20), rangeRight: r(30), rangeUp: r(10), rangeDown: r(15))
    }

    private func pose(yaw: Double, pitch: Double) -> HeadPose {
        HeadPose(timestamp: 0, yaw: r(yaw), pitch: r(pitch), roll: r(35))
    }

    func testNeutralMapsToCenter() {
        var mapper = PointerMapper(calibration: calibration(), sensitivity: 1, deadZoneDegrees: 0)
        XCTAssertEqual(mapper.map(pose(yaw: 0, pitch: 0)), .center)
    }

    func testAsymmetricRangesReachEachEdge() {
        var mapper = PointerMapper(calibration: calibration(), sensitivity: 1, deadZoneDegrees: 0)
        XCTAssertEqual(mapper.map(pose(yaw: 30, pitch: 0)).x, 1, accuracy: 1e-9)
        mapper.reset()
        XCTAssertEqual(mapper.map(pose(yaw: -20, pitch: 0)).x, 0, accuracy: 1e-9)
        mapper.reset()
        XCTAssertEqual(mapper.map(pose(yaw: 15, pitch: 0)).x, 0.75, accuracy: 1e-9)
        mapper.reset()
        XCTAssertEqual(mapper.map(pose(yaw: 0, pitch: 10)).y, 0, accuracy: 1e-9, "looking up reaches the top")
        mapper.reset()
        XCTAssertEqual(mapper.map(pose(yaw: 0, pitch: -15)).y, 1, accuracy: 1e-9, "looking down reaches the bottom")
    }

    func testClampsBeyondRange() {
        var mapper = PointerMapper(calibration: calibration(), sensitivity: 1, deadZoneDegrees: 0)
        let point = mapper.map(pose(yaw: 80, pitch: -60))
        XCTAssertEqual(point, NormalizedPoint(x: 1, y: 1))
    }

    func testRollIsIgnored() {
        var a = PointerMapper(calibration: calibration(), sensitivity: 1, deadZoneDegrees: 0)
        var b = a
        let tilted = HeadPose(timestamp: 0, yaw: r(5), pitch: r(2), roll: r(-30))
        let upright = HeadPose(timestamp: 0, yaw: r(5), pitch: r(2), roll: 0)
        XCTAssertEqual(a.map(tilted), b.map(upright))
    }

    func testSensitivityScalesMovement() {
        var mapper = PointerMapper(calibration: calibration(), sensitivity: 2, deadZoneDegrees: 0)
        XCTAssertEqual(mapper.map(pose(yaw: 15, pitch: 0)).x, 1, accuracy: 1e-9)
    }

    func testDeadZoneHoldsStillAgainstTremor() {
        var mapper = PointerMapper(calibration: calibration(), sensitivity: 1, deadZoneDegrees: 0.3)
        let first = mapper.map(pose(yaw: 5, pitch: 0))
        for wobble in [0.1, -0.2, 0.25, -0.15] {
            XCTAssertEqual(mapper.map(pose(yaw: 5 + wobble, pitch: 0)), first)
        }
    }

    func testDeadZoneTracksDeliberateMovementContinuously() {
        var mapper = PointerMapper(calibration: calibration(), sensitivity: 1, deadZoneDegrees: 0.3)
        _ = mapper.map(pose(yaw: 0, pitch: 0))
        var previous = 0.5
        for step in 1...20 {
            let x = mapper.map(pose(yaw: Double(step) * 0.5, pitch: 0)).x
            XCTAssertGreaterThan(x, previous)
            previous = x
        }
        // Lags the true position by at most the dead zone (0.3° of a 30° half-range).
        XCTAssertEqual(previous, 0.5 + 0.5 * (10 - 0.3) / 30, accuracy: 1e-9)
    }

    func testYawWrapAroundAtPi() {
        var mapper = PointerMapper(calibration: calibration(neutralYaw: r(179)), sensitivity: 1, deadZoneDegrees: 0)
        // -179° is 2° to the right of 179°, not 358° to the left.
        let point = mapper.map(HeadPose(timestamp: 0, yaw: r(-179), pitch: 0, roll: 0))
        XCTAssertEqual(point.x, 0.5 + 0.5 * 2 / 30, accuracy: 1e-9)
    }
}
