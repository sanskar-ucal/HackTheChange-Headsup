import XCTest
@testable import HeadsUpKit

final class PointerMapperTests: XCTestCase {
    private let r = AngleMath.radians

    private func calibration(neutralYaw: Double = 0) -> Calibration {
        Calibration(neutralYaw: neutralYaw, neutralPitch: 0, neutralRoll: 0,
                    rangeLeft: r(20), rangeRight: r(30), rangeUp: r(10), rangeDown: r(15))
    }

    /// Plain linear mapping: no dead zone, no precision damping.
    private func mapper(_ config: PointerMapper.Config = .init(), neutralYaw: Double = 0) -> PointerMapper {
        PointerMapper(calibration: calibration(neutralYaw: neutralYaw), config: config)
    }

    private func pose(yaw: Double, pitch: Double = 0, t: Double = 0) -> HeadPose {
        HeadPose(timestamp: t, yaw: r(yaw), pitch: r(pitch), roll: r(35))
    }

    private func x(_ m: inout PointerMapper, yaw: Double, t: Double = 0) -> Double {
        m.map(pose(yaw: yaw, t: t)).point.x
    }

    func testNeutralMapsToCenter() {
        var m = mapper()
        XCTAssertEqual(m.map(pose(yaw: 0)).point, .center)
    }

    func testAsymmetricRangesReachEachEdgeAtSensitivityOne() {
        var m = mapper()
        XCTAssertEqual(x(&m, yaw: 30), 1, accuracy: 1e-9)
        m = mapper()
        XCTAssertEqual(x(&m, yaw: -20), 0, accuracy: 1e-9)
        m = mapper()
        XCTAssertEqual(m.map(pose(yaw: 0, pitch: 10)).point.y, 0, accuracy: 1e-9, "looking up reaches the top")
        m = mapper()
        XCTAssertEqual(m.map(pose(yaw: 0, pitch: -15)).point.y, 1, accuracy: 1e-9, "looking down reaches the bottom")
    }

    func testClampsBeyondRangeAndReportsOvershoot() {
        var m = mapper()
        let mapped = m.map(pose(yaw: 80, pitch: -60))
        XCTAssertEqual(mapped.point, NormalizedPoint(x: 1, y: 1))
        XCTAssertEqual(mapped.overshoot.right, 50, accuracy: 1e-6)
        XCTAssertEqual(mapped.overshoot.down, 45, accuracy: 1e-6)
        XCTAssertEqual(mapped.overshoot.up, 0)
    }

    func testRollIsIgnored() {
        var a = mapper()
        var b = mapper()
        XCTAssertEqual(a.map(HeadPose(timestamp: 0, yaw: r(5), pitch: r(2), roll: r(-30))).point,
                       b.map(HeadPose(timestamp: 0, yaw: r(5), pitch: r(2), roll: 0)).point)
    }

    func testLowerSensitivityGivesSmallerCursorDeltaForSameHeadDelta() {
        var full = mapper(.init(sensitivity: 1))
        var calm = mapper(.init(sensitivity: 0.6))
        let fullDelta = x(&full, yaw: 10) - 0.5
        let calmDelta = x(&calm, yaw: 10) - 0.5
        XCTAssertLessThan(calmDelta, fullDelta)
        XCTAssertEqual(calmDelta / fullDelta, 0.6, accuracy: 1e-9)
    }

    func testLowSensitivityNeedsMoreTurnAndClampsAtEdge() {
        var m = mapper(.init(sensitivity: 0.5))
        XCTAssertEqual(x(&m, yaw: 30), 0.75, accuracy: 1e-9)
        m = mapper(.init(sensitivity: 0.5))
        XCTAssertEqual(x(&m, yaw: 90), 1, accuracy: 1e-9)
    }

    func testChangingSensitivityAppliesWithoutRecalibrating() {
        var m = mapper(.init(sensitivity: 1))
        XCTAssertEqual(x(&m, yaw: 15, t: 0), 0.75, accuracy: 1e-9)
        m.config.sensitivity = 0.5
        XCTAssertEqual(x(&m, yaw: 15, t: 0.04), 0.625, accuracy: 1e-9)
    }

    private func pure(yaw: Double, pitch: Double = 0, sensitivity: Double = 1) -> NormalizedPoint {
        PointerMapper.map(yaw: r(yaw), pitch: r(pitch), calibration: calibration(), sensitivity: sensitivity).point
    }

    /// Pixel distance in a 1000 × 800 pointing rect.
    private func pixels(_ a: NormalizedPoint, _ b: NormalizedPoint) -> Double {
        hypot((a.x - b.x) * 1000, (a.y - b.y) * 800)
    }

    func testMovingAwayAndReturningLandsOnTheSamePoint() {
        var m = mapper(.init(sensitivity: 0.6, deadZoneDegrees: 0.6, settleTime: 0.25))
        var t = 0.0
        func step(_ yaw: Double, _ pitch: Double) -> NormalizedPoint {
            defer { t += 0.04 }
            return m.map(pose(yaw: yaw, pitch: pitch, t: t)).point
        }
        var original = NormalizedPoint.center
        for _ in 0..<15 { original = step(5, 3) }               // settle at A
        for i in 1...12 { _ = step(5 - Double(i) * 1.25, 3 - Double(i) * 0.75) }  // to B
        for _ in 0..<8 { _ = step(-10, -6) }
        for i in 1...12 { _ = step(-10 + Double(i) * 1.25, -6 + Double(i) * 0.75) } // back to A
        var returned = NormalizedPoint.center
        for _ in 0..<15 { returned = step(5, 3) }
        XCTAssertLessThan(pixels(original, returned), 2)
        XCTAssertLessThan(pixels(returned, pure(yaw: 5, pitch: 3, sensitivity: 0.6)), 2, "the pure mapping")
    }

    func testPointingIsExactWhileMoving() {
        var m = mapper(.init(deadZoneDegrees: 0.6, settleTime: 0.25))
        for i in 0...40 {
            let yaw = Double(i) * 0.5  // 12.5 °/s
            let point = m.map(pose(yaw: yaw, t: Double(i) * 0.04)).point
            if i > 1 { XCTAssertEqual(point.x, pure(yaw: yaw).x, accuracy: 1e-9, "no trailing offset at \(yaw)°") }
        }
    }

    func testDeadZoneOnlyHoldsStill() {
        var m = mapper(.init(deadZoneDegrees: 0.6, settleTime: 0.25))
        for i in 0..<25 { _ = x(&m, yaw: 4, t: Double(i) * 0.04) }  // settled (and refreshed) at 4°
        let held = pure(yaw: 4).x
        for i in 25..<80 {
            let tremor = 4 + 0.5 * sin(Double(i) * 1.7)  // under the 0.6° dead zone
            XCTAssertEqual(x(&m, yaw: tremor, t: Double(i) * 0.04), held, accuracy: 1e-9, "sample \(i)")
        }
        // A deliberate move goes exactly to the new pose: the dead zone never shifts the mapping.
        XCTAssertEqual(x(&m, yaw: 6, t: 3.3), pure(yaw: 6).x, accuracy: 1e-9)
    }

    func testSamePoseGivesSamePointRegardlessOfHistory() {
        var fromLeft = mapper(.init(deadZoneDegrees: 0.6))
        var fromRight = mapper(.init(deadZoneDegrees: 0.6))
        for i in 0...20 { _ = x(&fromLeft, yaw: -15 + Double(i), t: Double(i) * 0.04) }   // arrive at 5°
        for i in 0...20 { _ = x(&fromRight, yaw: 25 - Double(i), t: Double(i) * 0.04) }   // arrive at 5°
        for i in 21...40 {
            _ = x(&fromLeft, yaw: 5, t: Double(i) * 0.04)
            _ = x(&fromRight, yaw: 5, t: Double(i) * 0.04)
        }
        XCTAssertEqual(x(&fromLeft, yaw: 5, t: 1.68), x(&fromRight, yaw: 5, t: 1.68), accuracy: 1e-9)
    }

    func testYawWrapAroundAtPi() {
        var m = mapper(neutralYaw: 179)
        // -179° is 2° to the right of 179°, not 358° to the left.
        let point = m.map(HeadPose(timestamp: 0, yaw: r(-179), pitch: 0, roll: 0)).point
        XCTAssertEqual(point.x, 0.5 + 0.5 * 2 / 30, accuracy: 1e-9)
    }
}
