import CoreGraphics
import XCTest
@testable import HeadsUpKit

@MainActor
final class AppCoordinatorTests: XCTestCase {
    typealias S = TraceSynth

    private func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat { hypot(a.x - b.x, a.y - b.y) }

    func testFirstLaunchFlowFromPermissionsThroughCalibrationToTracking() {
        let h = CoordinatorHarness(permissionsReady: false)
        h.coordinator.refreshPermissions()
        XCTAssertEqual(h.coordinator.state, .needsPermissions)

        h.permissions.status.accessibilityTrusted = true
        h.coordinator.refreshPermissions()
        XCTAssertEqual(h.coordinator.state, .waitingForHeadphones)
        XCTAssertFalse(h.keepAlive.isRunning)

        h.coordinator.handleConnection(.connected)
        XCTAssertEqual(h.coordinator.state, .calibrating(.center))
        XCTAssertTrue(h.keepAlive.isRunning)

        for (yaw, pitch) in [(0.0, 0.0), (-18, 13.5), (18, 13.5), (18, -13.5), (-18, -13.5), (0, 0)] {
            h.holdStill(3, yaw: yaw, pitch: pitch)
        }
        XCTAssertEqual(h.coordinator.state, .tracking)
        XCTAssertEqual(h.feedback.cues.filter { $0 == .calibrationStep }.count, 5, "center + 4 corners; the center check then finishes")
        XCTAssertTrue(h.feedback.cues.contains(.calibrationDone))
        XCTAssertEqual(AngleMath.degrees(h.store.calibration?.rangeRight ?? 0), 20, accuracy: 1)
        XCTAssertEqual(AngleMath.degrees(h.store.calibration?.rangeDown ?? 0), 15, accuracy: 1)
        XCTAssertTrue(h.cursor.moves.contains(CGPoint(x: 500, y: 400)), "pointer glides to center")
    }

    func testCalibrationIsFollowedByPracticeWhenEnabled() {
        var settings = CoordinatorHarness.testSettings
        settings.practiceEnabled = true
        let h = CoordinatorHarness(settings: settings)
        h.coordinator.refreshPermissions()
        h.coordinator.handleConnection(.connected)
        for (yaw, pitch) in [(0.0, 0.0), (-18, 13.5), (18, 13.5), (18, -13.5), (-18, -13.5), (0, 0)] {
            h.holdStill(3, yaw: yaw, pitch: pitch)
        }
        XCTAssertEqual(h.coordinator.state, .practicing)
        XCTAssertNotNil(h.coordinator.practice)
    }

    func testPracticeSuggestionIsAcceptedByNod() {
        var settings = CoordinatorHarness.testSettings
        settings.practiceEnabled = true
        settings.practiceDuration = 1
        let h = CoordinatorHarness(settings: settings)
        h.coordinator.refreshPermissions()
        h.coordinator.handleConnection(.connected)
        for (yaw, pitch) in [(0.0, 0.0), (-18, 13.5), (18, 13.5), (18, -13.5), (-18, -13.5), (0, 0)] {
            h.holdStill(3, yaw: yaw, pitch: pitch)
        }
        h.holdStill(1.2, yaw: -18, pitch: -13.5)
        XCTAssertEqual(h.coordinator.practice?.phase, .suggesting(1.1))
        h.feed(2, yaw: [S.constant(-18)], pitch: [S.constant(-13.5), S.nod(at: 0.3)])
        XCTAssertEqual(h.coordinator.state, .tracking)
        XCTAssertEqual(h.settingsUpdates.last?.sensitivity, 1.1)
        XCTAssertEqual(h.coordinator.settings.sensitivity, 1.1)
        XCTAssertEqual(h.cursor.clicks, [], "practice nods never click")
    }

    func testRejectedCalibrationRestarts() {
        let h = CoordinatorHarness()
        h.coordinator.refreshPermissions()
        h.coordinator.handleConnection(.connected)
        for (yaw, pitch) in [(0.0, 0.0), (-3, 13.5), (18, 13.5), (18, -13.5), (-3, -13.5), (0, 0)] {
            h.holdStill(3, yaw: yaw, pitch: pitch)
        }
        XCTAssertEqual(h.coordinator.state, .calibrating(.center))
        XCTAssertTrue(h.feedback.cues.contains(.error))
        XCTAssertNotNil(h.coordinator.calibrationMessage)
        XCTAssertNil(h.store.calibration)
        XCTAssertTrue(h.cursor.events.isEmpty, "no events while calibrating")
    }

    func testSavedCalibrationRequiresRecenterThenGlidesToCenter() {
        let h = CoordinatorHarness(savedCalibration: CoordinatorHarness.calibration)
        h.coordinator.refreshPermissions()
        h.coordinator.handleConnection(.connected)
        XCTAssertEqual(h.coordinator.state, .awaitingRecenter)
        h.holdStill(1.0)
        XCTAssertEqual(h.coordinator.state, .awaitingRecenter)
        XCTAssertTrue(h.cursor.events.isEmpty)
        h.holdStill(1.6)
        XCTAssertEqual(h.coordinator.state, .tracking)
        XCTAssertTrue(h.feedback.cues.contains(.recentered))
        XCTAssertGreaterThan(h.cursor.moves.count, 2)
        XCTAssertLessThan(distance(h.cursor.moves.first ?? .zero, CGPoint(x: 100, y: 100)),
                          distance(CGPoint(x: 500, y: 400), CGPoint(x: 100, y: 100)))
        XCTAssertLessThan(distance(h.cursor.moves.last ?? .zero, CGPoint(x: 500, y: 400)), 2)
    }

    func testTiltRightRecentersFromAwaitingRecenter() {
        let h = CoordinatorHarness(savedCalibration: CoordinatorHarness.calibration)
        h.coordinator.refreshPermissions()
        h.coordinator.handleConnection(.connected)
        h.feed(2.2, yaw: [S.pan(10)], roll: [S.plateau(25, from: 0.1, to: 2.0)])
        XCTAssertEqual(h.coordinator.state, .tracking)
    }

    func testTiltLeftTogglesPauseAndResume() {
        let h = CoordinatorHarness.tracking()
        XCTAssertEqual(h.coordinator.state, .tracking)

        h.feed(2.4, roll: [S.plateau(-25, from: 0.1, to: 2.0)])
        XCTAssertEqual(h.coordinator.state, .paused)
        XCTAssertEqual(h.coordinator.pauseReason, .user)
        XCTAssertEqual(h.feedback.cues.last, .paused)
        XCTAssertEqual(h.coordinator.pointerContext, .paused)

        h.holdStill(0.5)
        h.feed(2.4, roll: [S.plateau(-25, from: 0.1, to: 2.0)])
        XCTAssertEqual(h.coordinator.state, .tracking)
        XCTAssertEqual(h.feedback.cues.last, .resumed)
    }

    func testNoEventsPostedWhilePaused() {
        let h = CoordinatorHarness.tracking()
        h.coordinator.togglePause()
        XCTAssertEqual(h.coordinator.state, .paused)
        h.cursor.clear()

        h.feed(3, yaw: [S.pan(10), S.shake(at: 2.0)], pitch: [S.nod(at: 0.5), S.nod(at: 1.4)])
        h.feed(1, roll: [S.plateau(25, from: 0.1, to: 0.9)])
        h.holdStill(1, pitch: 25)
        XCTAssertEqual(h.cursor.events, [])
        XCTAssertEqual(h.scroll.calls, 0)
        XCTAssertEqual(h.coordinator.state, .paused)
    }

    func testDisconnectPausesAndReconnectNeedsRecenter() {
        let h = CoordinatorHarness.tracking()
        h.coordinator.handleConnection(.disconnected)
        XCTAssertEqual(h.coordinator.state, .paused)
        XCTAssertEqual(h.coordinator.pauseReason, .headphonesDisconnected)
        XCTAssertTrue(h.announcer.phrases.last?.contains("disconnected") ?? false)

        h.coordinator.handleConnection(.connected)
        XCTAssertEqual(h.coordinator.state, .awaitingRecenter)
        h.holdStill(2.6)
        XCTAssertEqual(h.coordinator.state, .tracking)
    }

    func testPointingFollowsHead() {
        let h = CoordinatorHarness.tracking()
        h.holdStill(2, yaw: 10, pitch: 7.5)
        guard let point = h.cursor.moves.last else { return XCTFail("no move") }
        XCTAssertEqual(point.x, 750, accuracy: 18)
        XCTAssertEqual(point.y, 200, accuracy: 18)
    }

    func testNodWhilePanningClicksAtRollbackPoint() {
        let h = CoordinatorHarness.tracking()
        h.cursor.clear()
        h.feed(2.4, yaw: [S.pan(15), S.noise(13)], pitch: [S.nod(at: 0.8), S.noise(14)])

        XCTAssertEqual(h.cursor.clicks.count, 1)
        guard let click = h.cursor.clicks.first else { return }
        XCTAssertEqual(click.y, 400, accuracy: 10)
        XCTAssertGreaterThan(click.x, 600, "the pan had moved the pointer right")
        XCTAssertTrue(h.feedback.cues.contains(.select))
        XCTAssertNotEqual(h.coordinator.state, .scrollMode, "a single nod is not a double nod")
    }

    func testShakePressesEscape() {
        let h = CoordinatorHarness.tracking()
        h.feed(2, yaw: [S.shake(at: 0.5)])
        XCTAssertEqual(h.cursor.keys, [.escape])
        XCTAssertTrue(h.feedback.cues.contains(.cancel))
    }

    func testSlowPanNeverClicks() {
        let h = CoordinatorHarness.tracking()
        h.feed(1.5, yaw: [S.pan(12)], pitch: [S.pan(-8)])
        XCTAssertEqual(h.cursor.clicks, [])
        XCTAssertEqual(h.cursor.keys, [])
        XCTAssertGreaterThan(h.cursor.moves.count, 20, "the pointer moved instead")
    }

    func testAllMovesStayOnScreen() {
        let h = CoordinatorHarness.tracking()
        h.feed(3, yaw: [S.pan(30)], pitch: [S.pan(-20)])
        for point in h.cursor.moves {
            XCTAssertTrue(CoordinatorHarness.geometry.mainDisplay.contains(point), "\(point)")
        }
    }

    func testMovesSkipSubPointChanges() {
        let h = CoordinatorHarness.tracking()
        let before = h.cursor.moves.count
        h.holdStill(2)
        XCTAssertEqual(h.cursor.moves.count, before, "no posts for < 0.5 pt changes")
    }

    func testMissingAccessibilityBlocksEverything() {
        let h = CoordinatorHarness(savedCalibration: CoordinatorHarness.calibration, permissionsReady: false)
        h.coordinator.refreshPermissions()
        h.coordinator.handleConnection(.connected)
        h.holdStill(3)
        h.feed(2, pitch: [S.nod(at: 0.5)])
        XCTAssertEqual(h.coordinator.state, .needsPermissions)
        XCTAssertEqual(h.cursor.events, [])
    }
}
