import XCTest
@testable import HeadsUpKit

final class CalibrationTests: XCTestCase {
    private let r = AngleMath.radians

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

    private let targets: [(Double, Double)] = [(0, 0), (-18, 13.5), (18, 13.5), (18, -13.5), (-18, -13.5), (0, 0)]

    private func run(_ blocks: [[HeadPose]]) -> [CalibrationSession.Update] {
        var session = CalibrationSession(settings: .defaults)
        var updates: [CalibrationSession.Update] = []
        var offset = 0.0
        for block in blocks {
            for var pose in block {
                pose.timestamp += offset
                let update = session.process(pose)
                if case .progress = update { continue }
                updates.append(update)
            }
            offset += (block.last?.timestamp ?? 0) + 0.04
        }
        return updates
    }

    private func still(yaw: Double, pitch: Double, duration: Double = 2.5) -> [HeadPose] {
        TraceSynth.trace(duration: duration,
                         yaw: [TraceSynth.constant(yaw), TraceSynth.noise(yaw + 1)],
                         pitch: [TraceSynth.constant(pitch), TraceSynth.noise(pitch + 2)])
    }

    func testSessionCapturesAllTargetsByDwell() {
        let updates = run(targets.map { still(yaw: $0.0, pitch: $0.1) })
        let captured = updates.compactMap { update -> CalibrationStep? in
            if case let .captured(step, _) = update { return step } else { return nil }
        }
        XCTAssertEqual(captured, [.center, .topLeft, .topRight, .bottomRight, .bottomLeft])
        guard case let .finished(result)? = updates.last else { return XCTFail("not finished: \(updates)") }
        XCTAssertEqual(AngleMath.degrees(result.rangeLeft), 20, accuracy: 0.2)
        XCTAssertEqual(AngleMath.degrees(result.rangeRight), 20, accuracy: 0.2)
        XCTAssertEqual(AngleMath.degrees(result.rangeUp), 15, accuracy: 0.2)
        XCTAssertEqual(AngleMath.degrees(result.rangeDown), 15, accuracy: 0.2)
    }

    func testMovingCaptureIsRejected() {
        let wobble = TraceSynth.Component(value: { sin(4 * .pi * $0) }, rate: { 4 * .pi * cos(4 * .pi * $0) })
        let updates = run([TraceSynth.trace(duration: 5, yaw: [wobble])])
        XCTAssertTrue(updates.contains(.rejected(.center)))
        XCTAssertFalse(updates.contains { if case .captured = $0 { return true } else { return false } })
    }

    func testCaptureIsTheMedianOfTheWindow() {
        var poses = (0..<19).map { HeadPose(timestamp: Double($0) * 0.04, yaw: 0, pitch: AngleMath.radians(2), roll: 0) }
        poses[3].yaw = AngleMath.radians(1.5)
        poses[9].yaw = AngleMath.radians(1.8)
        let median = CalibrationSession.median(of: poses)
        XCTAssertEqual(median.yaw, 0, accuracy: 1e-12)
        XCTAssertEqual(AngleMath.degrees(median.pitch), 2, accuracy: 1e-9)

        let seam = [179.0, -179.0, 179.5].map { HeadPose(timestamp: 0, yaw: AngleMath.radians($0), pitch: 0, roll: 0) }
        XCTAssertEqual(AngleMath.degrees(CalibrationSession.median(of: seam).yaw), 179.5, accuracy: 1e-9)
    }

    func testCenterDriftRedoesCalibration() {
        var blocks = targets.map { still(yaw: $0.0, pitch: $0.1) }
        blocks[5] = still(yaw: 4, pitch: 0)
        guard case let .failed(error)? = run(blocks).last,
              case let .centerDrifted(degrees) = error else { return XCTFail("expected a drift failure") }
        XCTAssertEqual(degrees, 4, accuracy: 0.1)
    }

    func testSessionDoesNotCaptureNextTargetWithoutMoving() {
        var session = CalibrationSession(settings: .defaults)
        var captures = 0
        for i in 0..<150 {
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
