import XCTest
@testable import HeadsUpKit

final class PointerMapperTests: XCTestCase {
    private let r = AngleMath.radians

    private func calibration(neutralYaw: Double = 0) -> Calibration {
        Calibration(neutralYaw: neutralYaw, neutralPitch: 0, neutralRoll: 0,
                    rangeLeft: r(20), rangeRight: r(30), rangeUp: r(10), rangeDown: r(15))
    }

    private func mapper(sensitivity: Double = 1, neutralYaw: Double = 0) -> PointerMapper {
        PointerMapper(calibration: calibration(neutralYaw: neutralYaw), config: .init(sensitivity: sensitivity))
    }

    private func pose(yaw: Double, pitch: Double = 0, t: Double = 0) -> HeadPose {
        HeadPose(timestamp: t, yaw: r(yaw), pitch: r(pitch), roll: r(35))
    }

    private func x(_ m: PointerMapper, yaw: Double) -> Double {
        m.map(pose(yaw: yaw)).point.x
    }

    /// Pixel distance in a 1000 × 800 pointing rect.
    private func pixels(_ a: NormalizedPoint, _ b: NormalizedPoint) -> Double {
        hypot((a.x - b.x) * 1000, (a.y - b.y) * 800)
    }

    func testNeutralMapsToCenter() {
        XCTAssertEqual(mapper().map(pose(yaw: 0)).point, .center)
    }

    func testAsymmetricRangesReachEachEdgeAtSensitivityOne() {
        let m = mapper()
        XCTAssertEqual(x(m, yaw: 30), 1, accuracy: 1e-9)
        XCTAssertEqual(x(m, yaw: -20), 0, accuracy: 1e-9)
        XCTAssertEqual(m.map(pose(yaw: 0, pitch: 10)).point.y, 0, accuracy: 1e-9, "looking up reaches the top")
        XCTAssertEqual(m.map(pose(yaw: 0, pitch: -15)).point.y, 1, accuracy: 1e-9, "looking down reaches the bottom")
    }

    func testClampsBeyondRangeAndReportsOvershoot() {
        let mapped = mapper().map(pose(yaw: 80, pitch: -60))
        XCTAssertEqual(mapped.point, NormalizedPoint(x: 1, y: 1))
        XCTAssertEqual(mapped.overshoot.right, 50, accuracy: 1e-6)
        XCTAssertEqual(mapped.overshoot.down, 45, accuracy: 1e-6)
        XCTAssertEqual(mapped.overshoot.up, 0)
    }

    func testRollIsIgnored() {
        let m = mapper()
        XCTAssertEqual(m.map(HeadPose(timestamp: 0, yaw: r(5), pitch: r(2), roll: r(-30))).point,
                       m.map(HeadPose(timestamp: 0, yaw: r(5), pitch: r(2), roll: 0)).point)
    }

    func testLowerSensitivityGivesSmallerCursorDeltaForSameHeadDelta() {
        let fullDelta = x(mapper(sensitivity: 1), yaw: 10) - 0.5
        let calmDelta = x(mapper(sensitivity: 0.6), yaw: 10) - 0.5
        XCTAssertLessThan(calmDelta, fullDelta)
        XCTAssertEqual(calmDelta / fullDelta, 0.6, accuracy: 1e-9)
    }

    func testLowSensitivityNeedsMoreTurnAndClampsAtEdge() {
        XCTAssertEqual(x(mapper(sensitivity: 0.5), yaw: 30), 0.75, accuracy: 1e-9)
        XCTAssertEqual(x(mapper(sensitivity: 0.5), yaw: 90), 1, accuracy: 1e-9)
    }

    func testChangingSensitivityAppliesWithoutRecalibrating() {
        var m = mapper(sensitivity: 1)
        XCTAssertEqual(x(m, yaw: 15), 0.75, accuracy: 1e-9)
        m.config.sensitivity = 0.5
        XCTAssertEqual(x(m, yaw: 15), 0.625, accuracy: 1e-9)
    }

    func testPointingIsAPureFunctionOfPose() {
        let m = mapper(sensitivity: 0.6)
        let original = m.map(pose(yaw: 5, pitch: 3, t: 0)).point
        // Wander far away and come back from the other side: same pose, same point.
        for i in 0...40 { _ = m.map(pose(yaw: 5 - Double(i), pitch: 3 - Double(i) * 0.5, t: Double(i) * 0.04)) }
        for i in 0...40 { _ = m.map(pose(yaw: -35 + Double(i), pitch: -17 + Double(i) * 0.5, t: 2 + Double(i) * 0.04)) }
        let returned = m.map(pose(yaw: 5, pitch: 3, t: 4)).point
        XCTAssertLessThan(pixels(original, returned), 2)
        XCTAssertEqual(original, returned)
        XCTAssertEqual(returned,
                       PointerMapper.map(yaw: r(5), pitch: r(3), calibration: calibration(), sensitivity: 0.6).point)
    }

    func testYawWrapAroundAtPi() {
        // -179° is 2° to the right of 179°, not 358° to the left.
        let point = mapper(neutralYaw: r(179)).map(HeadPose(timestamp: 0, yaw: r(-179), pitch: 0, roll: 0)).point
        XCTAssertEqual(point.x, 0.5 + 0.5 * 2 / 30, accuracy: 1e-9)
    }
}
