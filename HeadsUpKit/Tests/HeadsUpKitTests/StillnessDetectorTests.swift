import XCTest
@testable import HeadsUpKit

final class StillnessDetectorTests: XCTestCase {
    private let r = AngleMath.radians

    private func pose(_ t: Double, yaw: Double = 0, pitch: Double = 0) -> HeadPose {
        HeadPose(timestamp: t, yaw: r(yaw), pitch: r(pitch), roll: 0)
    }

    func testProgressGrowsWhileStillAndCapsAtOne() {
        var detector = StillnessDetector(toleranceDegrees: 1.5, duration: 2)
        XCTAssertEqual(detector.update(pose(0)), 0, "the first sample only sets the anchor")
        XCTAssertEqual(detector.update(pose(1, yaw: 1)), 0.5, accuracy: 1e-9)
        XCTAssertEqual(detector.update(pose(2, pitch: -1.4)), 1, accuracy: 1e-9)
        XCTAssertEqual(detector.update(pose(5)), 1, "capped")
    }

    func testMovingPastToleranceRestartsFromTheNewPose() {
        var detector = StillnessDetector(toleranceDegrees: 1.5, duration: 2)
        _ = detector.update(pose(0))
        XCTAssertEqual(detector.update(pose(1.5, yaw: 2)), 0)
        // Measured from the new anchor (yaw 2° at 1.5 s), not the original one.
        XCTAssertEqual(detector.update(pose(2.5, yaw: 2.5)), 0.5, accuracy: 1e-9)
    }

    func testRollIsIgnored() {
        var detector = StillnessDetector(toleranceDegrees: 1.5, duration: 1)
        _ = detector.update(pose(0))
        let tilted = HeadPose(timestamp: 1, yaw: 0, pitch: 0, roll: r(20))
        XCTAssertEqual(detector.update(tilted), 1, "tilt is handled by the tilt recognizer")
    }

    func testYawWrapsAroundPi() {
        var detector = StillnessDetector(toleranceDegrees: 1.5, duration: 1)
        _ = detector.update(pose(0, yaw: 179.5))
        XCTAssertEqual(detector.update(pose(0.5, yaw: -179.5)), 0.5, accuracy: 1e-9, "1° apart, not 359°")
    }

    func testResetForgetsTheAnchor() {
        var detector = StillnessDetector(toleranceDegrees: 1.5, duration: 1)
        _ = detector.update(pose(0))
        detector.reset()
        XCTAssertEqual(detector.update(pose(5)), 0)
    }

    func testZeroDurationCompletesOnTheSecondSample() {
        var detector = StillnessDetector(toleranceDegrees: 1.5, duration: 0)
        XCTAssertEqual(detector.update(pose(0)), 0)
        XCTAssertEqual(detector.update(pose(0.01)), 1)
    }
}

final class SampleRateMeterTests: XCTestCase {
    func testRatePerIntervalThenStartsOver() {
        var meter = SampleRateMeter()
        for _ in 0..<50 { meter.recordSample() }
        XCTAssertEqual(meter.takeRate(interval: 2), 25)
        XCTAssertEqual(meter.takeRate(interval: 1), 0, "each call starts a new interval")
    }

    func testNonPositiveIntervalReportsZero() {
        var meter = SampleRateMeter()
        meter.recordSample()
        XCTAssertEqual(meter.takeRate(interval: 0), 0)
        meter.recordSample()
        XCTAssertEqual(meter.takeRate(interval: 1), 1, "the zero-interval call still reset the count")
    }
}
