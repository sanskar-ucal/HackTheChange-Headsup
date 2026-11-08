import CoreGraphics
import Foundation
@testable import HeadsUpKit

/// Wires an `AppCoordinator` to mocks and feeds it synthetic poses on a virtual clock.
/// After every pose it renders one frame at the pose's timestamp (25 Hz frames).
@MainActor
final class CoordinatorHarness {
    typealias S = TraceSynth

    let motion: MockMotionSource
    let cursor: MockCursor
    let scroll: MockScroll
    let feedback: MockFeedback
    let announcer: MockAnnouncer
    let permissions: MockPermissions
    let store: InMemoryCalibrationStore
    let keepAlive: MockKeepAlive
    let targets: MockTargets
    let focus: MockFocusReader
    let speech: MockSpeech
    let inserter: MockInserter
    let coordinator: AppCoordinator
    private(set) var clock = 0.0
    private let now: Box<Double>
    private let saved: Box<[Settings]>

    /// 1000×800 display; ±20° yaw and ±15° pitch reach the edges at sensitivity 1.
    nonisolated static let geometry = ScreenGeometry(displays: [CGRect(x: 0, y: 0, width: 1000, height: 800)])
    nonisolated static let calibration = Calibration(
        neutralYaw: 0, neutralPitch: 0, neutralRoll: 0,
        rangeLeft: AngleMath.radians(20), rangeRight: AngleMath.radians(20),
        rangeUp: AngleMath.radians(15), rangeDown: AngleMath.radians(15))

    /// Settings for coordinator tests: sensitivity 1 and no precision damping so pointer
    /// positions are easy to predict (those features have their own unit tests).
    nonisolated static var testSettings: Settings {
        var settings = Settings.defaults
        settings.permissionPollInterval = 0
        settings.practiceEnabled = false
        settings.sensitivity = 1
        settings.precisionGain = 1
        return settings
    }

    init(savedCalibration: Calibration? = nil, permissionsReady: Bool = true, settings: Settings = testSettings) {
        motion = MockMotionSource()
        cursor = MockCursor()
        scroll = MockScroll()
        feedback = MockFeedback()
        announcer = MockAnnouncer()
        permissions = MockPermissions()
        permissions.status.accessibilityTrusted = permissionsReady
        store = InMemoryCalibrationStore(calibration: savedCalibration)
        keepAlive = MockKeepAlive()
        targets = MockTargets()
        focus = MockFocusReader()
        speech = MockSpeech()
        inserter = MockInserter()
        let now = Box(0.0)
        let saved = Box([Settings]())
        self.now = now
        self.saved = saved
        coordinator = AppCoordinator(
            dependencies: .init(
                motionSource: motion, cursor: cursor, scroll: scroll, feedback: feedback, announcer: announcer,
                permissions: permissions, calibrationStore: store, keepAlive: keepAlive,
                frameClock: MockFrameClock(), targets: targets, focusReader: focus, speech: speech,
                textInserter: inserter,
                screenGeometry: { CoordinatorHarness.geometry }, isAppActive: { false },
                clock: { now.value }, schedule: { _, work in work() }, updateSettings: { saved.value.append($0) }),
            settings: settings)
    }

    /// Settings the coordinator asked to persist.
    var settingsUpdates: [Settings] { saved.value }

    func feed(_ duration: Double, yaw: [S.Component] = [], pitch: [S.Component] = [], roll: [S.Component] = []) {
        for var pose in S.trace(duration: duration, yaw: yaw, pitch: pitch, roll: roll) {
            pose.timestamp += clock
            now.value = pose.timestamp
            coordinator.handle(pose: pose)
            coordinator.renderFrame(at: pose.timestamp)
        }
        clock += duration
    }

    func holdStill(_ duration: Double, yaw: Double = 0, pitch: Double = 0) {
        feed(duration, yaw: [S.constant(yaw), S.noise(1)], pitch: [S.constant(pitch), S.noise(2)])
    }

    /// Saved calibration → connect → auto-recenter by holding still → tracking.
    static func tracking(settings: Settings = testSettings) -> CoordinatorHarness {
        let harness = CoordinatorHarness(savedCalibration: calibration, settings: settings)
        harness.coordinator.refreshPermissions()
        harness.coordinator.handleConnection(.connected)
        harness.holdStill(2.6)
        return harness
    }
}

/// A mutable value shared with closures handed to the coordinator.
@MainActor
final class Box<Value> {
    var value: Value
    init(_ value: Value) { self.value = value }
}
