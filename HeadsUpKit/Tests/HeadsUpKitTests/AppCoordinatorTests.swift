import CoreGraphics
import XCTest
@testable import HeadsUpKit

/// Wires an `AppCoordinator` to mocks and feeds it synthetic poses on a virtual clock.
@MainActor
final class CoordinatorHarness {
    typealias S = TraceSynth

    let motion: MockMotionSource
    let cursor: MockCursor
    let feedback: MockFeedback
    let announcer: MockAnnouncer
    let permissions: MockPermissions
    let store: InMemoryCalibrationStore
    let keepAlive: MockKeepAlive
    let coordinator: AppCoordinator
    private(set) var clock = 0.0

    /// 1000×800 display; ±20° yaw and ±15° pitch reach the edges.
    static let geometry = ScreenGeometry(displays: [CGRect(x: 0, y: 0, width: 1000, height: 800)])
    static let calibration = Calibration(
        neutralYaw: 0, neutralPitch: 0, neutralRoll: 0,
        rangeLeft: AngleMath.radians(20), rangeRight: AngleMath.radians(20),
        rangeUp: AngleMath.radians(15), rangeDown: AngleMath.radians(15))

    init(savedCalibration: Calibration? = nil, permissionsReady: Bool = true) {
        motion = MockMotionSource()
        cursor = MockCursor()
        feedback = MockFeedback()
        announcer = MockAnnouncer()
        permissions = MockPermissions()
        permissions.status.accessibilityTrusted = permissionsReady
        store = InMemoryCalibrationStore(calibration: savedCalibration)
        keepAlive = MockKeepAlive()
        var settings = Settings.defaults
        settings.permissionPollInterval = 0
        coordinator = AppCoordinator(
            dependencies: .init(
                motionSource: motion, cursor: cursor, feedback: feedback, announcer: announcer,
                permissions: permissions, calibrationStore: store, keepAlive: keepAlive,
                screenGeometry: { CoordinatorHarness.geometry }, isAppActive: { false }),
            settings: settings)
    }

    func feed(_ duration: Double, yaw: [S.Component] = [], pitch: [S.Component] = [], roll: [S.Component] = []) {
        for var pose in S.trace(duration: duration, yaw: yaw, pitch: pitch, roll: roll) {
            pose.timestamp += clock
            coordinator.handle(pose: pose)
        }
        clock += duration
    }

    func holdStill(_ duration: Double, yaw: Double = 0, pitch: Double = 0) {
        feed(duration, yaw: [S.constant(yaw), S.noise(1)], pitch: [S.constant(pitch), S.noise(2)])
    }

    /// Saved calibration → connect → auto-recenter by holding still → tracking.
    static func tracking() -> CoordinatorHarness {
        let harness = CoordinatorHarness(savedCalibration: calibration)
        harness.coordinator.refreshPermissions()
        harness.coordinator.handleConnection(.connected)
        harness.holdStill(2.6)
        return harness
    }
}

@MainActor
final class AppCoordinatorTests: XCTestCase {
    typealias S = TraceSynth

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

        for (yaw, pitch) in [(0.0, 0.0), (-18, 13.5), (18, 13.5), (18, -13.5), (-18, -13.5)] {
            h.holdStill(3, yaw: yaw, pitch: pitch)
        }
        XCTAssertEqual(h.coordinator.state, .tracking)
        XCTAssertEqual(h.feedback.cues.filter { $0 == .calibrationStep }.count, 4)
        XCTAssertTrue(h.feedback.cues.contains(.calibrationDone))
        let saved = try? XCTUnwrap(h.store.calibration)
        XCTAssertEqual(AngleMath.degrees(saved?.rangeRight ?? 0), 20, accuracy: 1)
        XCTAssertEqual(AngleMath.degrees(saved?.rangeDown ?? 0), 15, accuracy: 1)
        XCTAssertTrue(h.cursor.events.contains(.move(CGPoint(x: 500, y: 400))), "cursor jumps to center")
    }

    func testRejectedCalibrationRestarts() {
        let h = CoordinatorHarness()
        h.coordinator.refreshPermissions()
        h.coordinator.handleConnection(.connected)
        // Left corners only 3° from center: the left range is too small.
        for (yaw, pitch) in [(0.0, 0.0), (-3, 13.5), (18, 13.5), (18, -13.5), (-3, -13.5)] {
            h.holdStill(3, yaw: yaw, pitch: pitch)
        }
        XCTAssertEqual(h.coordinator.state, .calibrating(.center))
        XCTAssertTrue(h.feedback.cues.contains(.error))
        XCTAssertNotNil(h.coordinator.calibrationMessage)
        XCTAssertNil(h.store.calibration)
        XCTAssertTrue(h.cursor.events.isEmpty, "no events while calibrating")
    }

    func testSavedCalibrationRequiresRecenterThenTracks() {
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
        XCTAssertEqual(h.cursor.events.first, .move(CGPoint(x: 500, y: 400)))
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
        h.feed(1, roll: [S.plateau(25, from: 0.1, to: 0.9)])  // tilt right is ignored while paused
        XCTAssertEqual(h.cursor.events, [])
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
        h.holdStill(2, yaw: 10, pitch: 7.5)  // half-way right and half-way up
        guard case let .move(point)? = h.cursor.events.last else { return XCTFail("no move") }
        // Within the 0.3° dead-zone lag (≈ 8 px here) of the exact mapping.
        XCTAssertEqual(point.x, 750, accuracy: 10)
        XCTAssertEqual(point.y, 200, accuracy: 10)
    }

    func testNodWhilePanningClicksAtRollbackPoint() {
        let h = CoordinatorHarness.tracking()
        h.cursor.clear()
        h.feed(2.4, yaw: [S.pan(15), S.noise(13)], pitch: [S.nod(at: 0.8), S.noise(14)])

        XCTAssertEqual(h.cursor.clicks.count, 1)
        guard let click = h.cursor.clicks.first,
              let clickIndex = h.cursor.events.firstIndex(of: .click(click)),
              case let .move(beforeOnset)? = h.cursor.events[..<clickIndex].last(where: {
                  if case .move = $0 { return true } else { return false }
              })
        else { return XCTFail("expected moves before the click") }

        // Rolled back to before the nod: vertically at the neutral line, not dragged down.
        XCTAssertEqual(click.y, 400, accuracy: 10)
        // Horizontally where the pan had brought the cursor just before onset.
        XCTAssertEqual(click.x, beforeOnset.x, accuracy: 50)
        XCTAssertGreaterThan(click.x, 600, "the pan had moved the cursor right")
        XCTAssertTrue(h.feedback.cues.contains(.select))
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
        XCTAssertGreaterThan(h.cursor.events.count, 20, "the cursor moved instead")
    }

    func testAllMovesStayOnScreen() {
        let h = CoordinatorHarness.tracking()
        h.feed(3, yaw: [S.pan(30)], pitch: [S.pan(-20)])
        for case let .move(point) in h.cursor.events {
            XCTAssertTrue(CoordinatorHarness.geometry.mainDisplay.contains(point), "\(point)")
        }
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
