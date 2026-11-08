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

    func testPrecisionDampingAppliedBelowThreshold() {
        // 5 °/s is well below the 15 °/s precision speed: only half the travel.
        var m = mapper(.init(precisionSpeedDegPerSec: 15, precisionGain: 0.5))
        var last = 0.0
        for i in 0...50 { last = x(&m, yaw: 5 * Double(i) * 0.04, t: Double(i) * 0.04) }  // 0 → 10°
        XCTAssertEqual(last, 0.5 + 0.5 * 5 / 30, accuracy: 0.01)
    }

    func testDeliberateMovementGetsFullTravel() {
        var m = mapper(.init(precisionSpeedDegPerSec: 15, precisionGain: 0.5))
        var last = 0.0
        for i in 0...25 {
            let t = Double(i) * 0.04
            last = x(&m, yaw: min(60 * t, 20), t: t)  // 60 °/s to 20°, then hold
        }
        XCTAssertEqual(last, 0.5 + 0.5 * 20 / 30, accuracy: 0.01)
    }

    func testHysteresisPreventsCreepFromSmallNoise() {
        var m = mapper(.init(deadZoneDegrees: 0.6, deadZoneStartDegrees: 1.0, settleTime: 0.25))
        _ = x(&m, yaw: 0, t: 0)
        for i in 1...12 { XCTAssertEqual(x(&m, yaw: 0, t: Double(i) * 0.04), 0.5) }  // settle
        for i in 13...100 {
            let noise = 0.7 * sin(Double(i) * 1.7)  // ±0.7°: more than the moving dead zone
            XCTAssertEqual(x(&m, yaw: noise, t: Double(i) * 0.04), 0.5, "sample \(i)")
        }
    }

    func testDeadZoneTracksDeliberateMovementContinuously() {
        var m = mapper(.init(deadZoneDegrees: 0.6, deadZoneStartDegrees: 1.0, settleTime: 0.25))
        _ = x(&m, yaw: 0, t: 0)
        var previous = 0.5
        var values: [Double] = []
        for step in 1...20 {
            let value = x(&m, yaw: Double(step) * 0.5, t: Double(step) * 0.04)
            XCTAssertGreaterThanOrEqual(value, previous)
            previous = value
            values.append(value)
        }
        XCTAssertEqual(values.first, 0.5, "the first 0.5° step is inside the 1° start threshold")
        // While moving the output trails by the 0.6° moving dead zone.
        XCTAssertEqual(previous, 0.5 + 0.5 * (10 - 0.6) / 30, accuracy: 1e-9)
    }

    func testYawWrapAroundAtPi() {
        var m = mapper(neutralYaw: 179)
        // -179° is 2° to the right of 179°, not 358° to the left.
        let point = m.map(HeadPose(timestamp: 0, yaw: r(-179), pitch: 0, roll: 0)).point
        XCTAssertEqual(point.x, 0.5 + 0.5 * 2 / 30, accuracy: 1e-9)
    }
}
