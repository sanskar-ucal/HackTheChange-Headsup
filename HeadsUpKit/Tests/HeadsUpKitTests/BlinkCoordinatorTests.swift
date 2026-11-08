import CoreGraphics
import XCTest
@testable import HeadsUpKit

@MainActor
final class BlinkCoordinatorTests: XCTestCase {
    typealias S = TraceSynth

    /// Closures (seconds from now) of a deliberate double / triple blink.
    private let double: [ClosedRange<Double>] = [0.21...0.39, 0.61...0.79]
    private let triple: [ClosedRange<Double>] = [0.21...0.39, 0.61...0.79, 1.01...1.19]

    private static var blinkSettings: HeadsUpSettings {
        var settings = CoordinatorHarness.testSettings
        settings.blinkGesturesEnabled = true
        return settings
    }

    /// Started coordinator with a saved calibration, tracking, camera baseline learned.
    private func tracking(settings: HeadsUpSettings = blinkSettings,
                          prepare: (CoordinatorHarness) -> Void = { _ in }) -> CoordinatorHarness {
        let h = CoordinatorHarness(savedCalibration: CoordinatorHarness.calibration, settings: settings)
        prepare(h)
        h.coordinator.start()
        h.coordinator.handleConnection(.connected)
        h.holdStill(2.6)
        h.feedEyes(1)
        return h
    }

    // MARK: Camera lifecycle

    func testCameraStaysOffWhileBlinkGesturesAreOff() {
        let h = tracking(settings: CoordinatorHarness.testSettings)
        XCTAssertEqual(h.coordinator.state, .tracking)
        XCTAssertEqual(h.blink.startCount, 0)
        XCTAssertEqual(h.blink.requestCount, 0)
        XCTAssertEqual(h.coordinator.cameraStatus, .off)
    }

    func testEnablingStartsCameraAndDisablingStopsIt() {
        let h = tracking(settings: CoordinatorHarness.testSettings)
        h.coordinator.apply(settings: Self.blinkSettings)
        XCTAssertTrue(h.blink.isRunning)
        XCTAssertEqual(h.coordinator.cameraStatus, .running)

        h.coordinator.apply(settings: CoordinatorHarness.testSettings)
        XCTAssertFalse(h.blink.isRunning)
        XCTAssertEqual(h.coordinator.cameraStatus, .off)
        h.feedEyes(2, closed: double, stale: true)
        XCTAssertEqual(h.cursor.clicks, [], "frames still in flight after stop never act")
    }

    func testCameraOffWhileWaitingForAirPodsAndCalibrating() {
        let h = CoordinatorHarness(settings: Self.blinkSettings)
        h.coordinator.start()
        XCTAssertEqual(h.coordinator.state, .waitingForHeadphones)
        XCTAssertFalse(h.blink.isRunning)
        XCTAssertEqual(h.coordinator.cameraStatus, .standby)

        h.coordinator.handleConnection(.connected)
        XCTAssertEqual(h.coordinator.state, .calibrating(.center))
        XCTAssertFalse(h.blink.isRunning)
        XCTAssertEqual(h.blink.startCount, 0)
    }

    func testStopTurnsCameraOff() {
        let h = tracking()
        XCTAssertTrue(h.blink.isRunning)
        h.coordinator.stop()
        XCTAssertFalse(h.blink.isRunning)
    }

    // MARK: Gestures

    func testDoubleBlinkClicksOnceAtThePointer() {
        let h = tracking()
        let pointer = h.cursor.currentPosition
        h.cursor.clear()
        h.feedEyes(2, closed: double)
        XCTAssertEqual(h.cursor.clicks, [pointer])
        XCTAssertEqual(h.cursor.keys, [])
        XCTAssertEqual(h.feedback.cues.filter { $0 == .select }.count, 1)
        XCTAssertEqual(h.coordinator.lastGesture, .doubleBlink)
        XCTAssertEqual(h.coordinator.telemetry.blink.lastCommand, .select)
    }

    func testDoubleBlinkHoldsThePointerLikeANodClick() {
        var settings = Self.blinkSettings
        settings.holdAfterClick = 1
        let h = tracking(settings: settings)
        h.cursor.clear()
        h.feedEyes(2, closed: double)  // clicks at ≈1.3 s, holds until ≈2.3 s
        XCTAssertEqual(h.cursor.clicks.count, 1)
        h.holdStill(0.25, yaw: 10)  // still inside "hold after click": the pointer stays put
        XCTAssertEqual(h.cursor.moves, [])
        h.holdStill(1.5, yaw: 10)
        XCTAssertFalse(h.cursor.moves.isEmpty, "then it follows the head again")
    }

    func testTripleBlinkPressesEscapeWithoutClicking() {
        let h = tracking()
        h.cursor.clear()
        h.feedEyes(3, closed: triple)
        XCTAssertEqual(h.cursor.keys, [.escape])
        XCTAssertEqual(h.cursor.clicks, [], "never a click first")
        XCTAssertTrue(h.feedback.cues.contains(.cancel))
        XCTAssertFalse(h.feedback.cues.contains(.select))
        XCTAssertEqual(h.coordinator.lastGesture, .tripleBlink)
    }

    func testSingleAndOrdinaryBlinksDoNothing() {
        let h = tracking()
        h.cursor.clear()
        h.feedEyes(2, closed: [0.21...0.39])
        h.feedEyes(12, closed: [1.0...1.15, 3.5...3.7, 6.2...6.35, 9.0...9.3])
        XCTAssertEqual(h.cursor.events.filter { if case .move = $0 { return false } else { return true } }, [])
        XCTAssertGreaterThanOrEqual(h.coordinator.telemetry.blink.blinksSeen, 4)
    }

    func testCooldownBlocksImmediateRepeat() {
        let h = tracking()
        h.cursor.clear()
        // Second double blink starts right after the first one selects.
        h.feedEyes(3, closed: double + [1.41...1.59, 1.81...1.99])
        XCTAssertEqual(h.cursor.clicks.count, 1)
        h.feedEyes(2, closed: double)
        XCTAssertEqual(h.cursor.clicks.count, 2, "after the cooldown a double blink works again")
    }

    func testFaceLossOrSecondFaceMidSequenceCancels() {
        let h = tracking()
        h.cursor.clear()
        h.feedEyes(2, closed: double, readings: [(0.48...0.52, .noFace)])
        h.feedEyes(2, closed: double, readings: [(0.48...0.52, .multipleFaces)])
        h.feedEyes(2, closed: double, readings: [(0.48...0.52, .eyesNotFound)])
        XCTAssertEqual(h.cursor.clicks, [])
        XCTAssertEqual(h.coordinator.telemetry.blink.face, .tracked)
    }

    func testHeadGesturesStillWorkWithBlinksOn() {
        let h = tracking()
        h.cursor.clear()
        h.feed(2, pitch: [S.nod(at: 0.3)])
        XCTAssertEqual(h.cursor.clicks.count, 1)
        h.feed(2, yaw: [S.shake(at: 0.5)])
        XCTAssertEqual(h.cursor.keys, [.escape])
    }

    // MARK: State gates

    func testPausedTurnsCameraOffAndNeverClicks() {
        let h = tracking()
        h.coordinator.togglePause()
        XCTAssertEqual(h.coordinator.state, .paused)
        XCTAssertFalse(h.blink.isRunning)
        XCTAssertEqual(h.coordinator.cameraStatus, .standby)
        h.cursor.clear()
        h.feedEyes(3, closed: triple, stale: true)
        h.feedEyes(2, closed: double, stale: true)
        XCTAssertEqual(h.cursor.events, [])

        h.coordinator.togglePause()
        XCTAssertEqual(h.coordinator.state, .tracking)
        XCTAssertTrue(h.blink.isRunning, "camera resumes with tracking")
    }

    func testDisconnectStopsCamera() {
        let h = tracking()
        h.coordinator.handleConnection(.disconnected)
        XCTAssertFalse(h.blink.isRunning)
        h.feedEyes(2, closed: double, stale: true)
        XCTAssertEqual(h.cursor.clicks, [])
    }

    func testBlinksIgnoredWhileListening() {
        let h = tracking()
        h.focus.focused = FocusedElementInfo(role: "AXTextField", subrole: "AXSearchField")
        h.feed(2, pitch: [S.nod(at: 0.3)])
        XCTAssertEqual(h.coordinator.state, .listening)
        XCTAssertTrue(h.blink.isRunning, "the short voice mode keeps the camera on")
        h.feedEyes(2, closed: double)
        h.feedEyes(3, closed: triple)
        XCTAssertEqual(h.cursor.clicks.count, 1, "only the nod")
        XCTAssertEqual(h.cursor.keys, [])
        XCTAssertEqual(h.coordinator.state, .listening)
    }

    func testSequenceStartedBeforeLeavingTrackingNeverFiresLater() {
        let h = tracking()
        h.cursor.clear()
        h.feedEyes(0.5, closed: [0.21...0.39])  // first blink…
        XCTAssertEqual(h.coordinator.telemetry.blink.pendingBlinks, 1)
        h.coordinator.togglePause()
        h.coordinator.togglePause()  // …pause and resume in between…
        XCTAssertEqual(h.coordinator.telemetry.blink.pendingBlinks, 0)
        h.feedEyes(1)
        h.feedEyes(2, closed: [0.11...0.29])  // …and the second blink alone does nothing
        XCTAssertEqual(h.cursor.clicks, [])
    }

    // MARK: Permission and camera failures

    func testDeniedCameraReportsStatusWithoutActions() {
        let h = tracking { $0.blink.authorization = .denied }
        XCTAssertEqual(h.coordinator.cameraStatus, .denied)
        XCTAssertTrue(h.coordinator.cameraStatus.isProblem)
        XCTAssertEqual(h.cursor.clicks, [])
    }

    func testTurningOnAsksForCameraAccessOnce() {
        let h = tracking(settings: CoordinatorHarness.testSettings) { $0.blink.authorization = .notDetermined }
        XCTAssertEqual(h.blink.requestCount, 0, "no prompt while the feature is off")
        h.coordinator.apply(settings: Self.blinkSettings)
        XCTAssertEqual(h.blink.requestCount, 1)
        XCTAssertEqual(h.coordinator.cameraStatus, .running)
        XCTAssertTrue(h.blink.isRunning)
    }

    func testRefusingCameraAccessShowsDenied() {
        let h = tracking(settings: CoordinatorHarness.testSettings) {
            $0.blink.authorization = .notDetermined
            $0.blink.grantsAccess = false
        }
        h.coordinator.apply(settings: Self.blinkSettings)
        XCTAssertEqual(h.coordinator.cameraStatus, .denied)
        h.feedEyes(2, closed: double)
        XCTAssertEqual(h.cursor.clicks.count, 0)
    }

    func testCameraFailureResetsSequenceAndRetryRestarts() {
        let h = tracking()
        h.cursor.clear()
        h.feedEyes(0.5, closed: [0.21...0.39])
        h.blink.emit(.status(.failed))
        XCTAssertEqual(h.coordinator.cameraStatus, .failed)
        h.feedEyes(2, closed: [0.11...0.29])
        XCTAssertEqual(h.cursor.clicks, [])

        let starts = h.blink.startCount
        h.coordinator.retryBlinkCamera()
        XCTAssertEqual(h.blink.startCount, starts + 1)
        XCTAssertEqual(h.coordinator.cameraStatus, .running)
        h.feedEyes(1)  // relearn the open-eye baseline
        h.feedEyes(2, closed: double)
        XCTAssertEqual(h.cursor.clicks.count, 1)
    }

    func testNoCameraSourceReportsNoCamera() {
        let h = CoordinatorHarness(settings: Self.blinkSettings)
        let bare = AppCoordinator(dependencies: .init(
            motionSource: h.motion, cursor: h.cursor, scroll: h.scroll, feedback: h.feedback, announcer: h.announcer,
            permissions: h.permissions, calibrationStore: h.store, keepAlive: h.keepAlive,
            frameClock: MockFrameClock(), focusReader: h.focus, speech: h.speech, textInserter: h.inserter,
            screenGeometry: { CoordinatorHarness.geometry }, isAppActive: { false }, clock: { 0 },
            schedule: { _, work in work() }, updateSettings: { _ in }), settings: Self.blinkSettings)
        bare.start()
        XCTAssertEqual(bare.cameraStatus, .noCamera)
        bare.stop()
    }
}
