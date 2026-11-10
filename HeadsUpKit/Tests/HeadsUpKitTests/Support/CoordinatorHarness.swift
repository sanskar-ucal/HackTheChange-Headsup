import CoreGraphics
import Foundation
@testable import HeadsUpKit

/// Wires an `AppCoordinator` to mocks and feeds it synthetic poses on a virtual clock.
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
    let focus: MockFocusReader
    let speech: MockSpeech
    let inserter: MockInserter
    let blink: MockBlinkSource
    let coordinator: AppCoordinator
    private(set) var clock = 0.0
    private let now: Box<Double>
    private let saved: Box<[HeadsUpSettings]>

    nonisolated static let geometry = ScreenGeometry(displays: [CGRect(x: 0, y: 0, width: 1000, height: 800)])
    nonisolated static let calibration = Calibration(
        neutralYaw: 0, neutralPitch: 0, neutralRoll: 0,
        rangeLeft: AngleMath.radians(20), rangeRight: AngleMath.radians(20),
        rangeUp: AngleMath.radians(15), rangeDown: AngleMath.radians(15))

    nonisolated static var testSettings: HeadsUpSettings {
        var settings = HeadsUpSettings.defaults
        settings.permissionPollInterval = 0
        settings.practiceEnabled = false
        settings.sensitivity = 1
        return settings
    }

    init(savedCalibration: Calibration? = nil, permissionsReady: Bool = true, settings: HeadsUpSettings = testSettings) {
        motion = MockMotionSource()
        cursor = MockCursor()
        scroll = MockScroll()
        feedback = MockFeedback()
        announcer = MockAnnouncer()
        permissions = MockPermissions()
        permissions.status.accessibilityTrusted = permissionsReady
        store = InMemoryCalibrationStore(calibration: savedCalibration)
        keepAlive = MockKeepAlive()
        focus = MockFocusReader()
        speech = MockSpeech()
        inserter = MockInserter()
        blink = MockBlinkSource()
        let now = Box(0.0)
        let saved = Box([HeadsUpSettings]())
        self.now = now
        self.saved = saved
        coordinator = AppCoordinator(
            dependencies: .init(
                motionSource: motion, cursor: cursor, scroll: scroll, feedback: feedback, announcer: announcer,
                permissions: permissions, calibrationStore: store, keepAlive: keepAlive,
                frameClock: MockFrameClock(), focusReader: focus, speech: speech,
                textInserter: inserter,
                screenGeometry: { CoordinatorHarness.geometry }, isAppActive: { false },
                clock: { now.value }, schedule: { _, work in work() }, updateSettings: { saved.value.append($0) },
                blinkSource: blink),
            settings: settings)
    }

    var settingsUpdates: [HeadsUpSettings] { saved.value }

    func feed(_ duration: Double, yaw: [S.Component] = [], pitch: [S.Component] = [], roll: [S.Component] = []) {
        for var pose in S.trace(duration: duration, yaw: yaw, pitch: pitch, roll: roll) {
            pose.timestamp += clock
            now.value = pose.timestamp
            coordinator.handle(pose: pose)
            coordinator.renderFrame(at: pose.timestamp)
        }
        clock += duration
    }

    func feed(poses: [HeadPose], each: (HeadPose) -> Void = { _ in }) {
        guard let last = poses.last else { return }
        for var pose in poses {
            pose.timestamp += clock
            now.value = pose.timestamp
            coordinator.handle(pose: pose)
            coordinator.renderFrame(at: pose.timestamp)
            each(pose)
        }
        clock += last.timestamp + 0.04
    }

    func holdStill(_ duration: Double, yaw: Double = 0, pitch: Double = 0) {
        feed(duration, yaw: [S.constant(yaw), S.noise(1)], pitch: [S.constant(pitch), S.noise(2)])
    }

    /// Feeds camera eye readings at 30 Hz on the shared clock, rendering a frame after each.
    /// Eyes are closed during `closed` (seconds from now); `readings` overrides frames,
    /// e.g. a lost face. `stale` delivers through the handler of an already stopped camera.
    func feedEyes(_ duration: Double, closed: [ClosedRange<Double>] = [],
                  readings: [(ClosedRange<Double>, EyeReading)] = [], stale: Bool = false) {
        let step = 1.0 / 30
        for index in 0..<Int((duration / step).rounded()) {
            let t = Double(index) * step
            var reading = EyeReading.eyes(openness: closed.contains { $0.contains(t) } ? 0.08 : 0.32)
            if let override = readings.first(where: { $0.0.contains(t) }) { reading = override.1 }
            now.value = clock + t
            let event = BlinkSourceEvent.observation(EyeObservation(timestamp: clock + t, reading: reading))
            if stale { blink.emitStale(event) } else { blink.emit(event) }
            coordinator.renderFrame(at: clock + t)
        }
        clock += duration
    }

    /// Saved calibration → connect → auto-recenter by holding still → tracking.
    static func tracking(settings: HeadsUpSettings = testSettings) -> CoordinatorHarness {
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
