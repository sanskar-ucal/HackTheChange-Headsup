import CoreGraphics
import Foundation
import OSLog

/// Progress of a hold (tilt-hold or auto-recenter) for the cursor halo.
public struct HoldProgress: Sendable, Equatable {
    public var gesture: HeadGesture
    public var fraction: Double
}

/// Owns the app state machine and wires motion → processing → output.
///
/// States: needsPermissions → waitingForHeadphones → calibrating → tracking ⇄ paused.
/// A launch with a saved calibration, or a reconnect, goes through awaitingRecenter
/// because the AirPods' yaw reference resets. Synthetic events are only posted in
/// `.tracking` (see `post(_:)`).
@MainActor
public final class AppCoordinator: ObservableObject {
    @Published public private(set) var state: AppState = .needsPermissions
    @Published public private(set) var pauseReason: PauseReason?
    @Published public private(set) var permissionStatus: PermissionStatus
    @Published public internal(set) var isHeadphonesConnected = false
    @Published public internal(set) var holdProgress: HoldProgress?
    @Published public internal(set) var calibrationProgress: Double = 0
    @Published public internal(set) var calibrationMessage: String?
    @Published public internal(set) var lastGesture: HeadGesture?

    public let telemetry: LiveTelemetry
    public let recorder: MotionRecorder
    public internal(set) var settings: Settings
    public internal(set) var calibration: Calibration?

    let deps: Dependencies
    let dispatcher: ActionDispatcher
    var needsRecenter: Bool
    var poseFilter: PoseFilter
    var tilt: TiltHoldRecognizer
    var stillness: StillnessDetector
    var engine: TrackingEngine?
    var calibrationSession: CalibrationSession?
    var lastFilteredPose: HeadPose?
    var meter = SampleRateMeter()
    var lastTelemetryTime: TimeInterval = -.infinity
    static let log = Logger(subsystem: "com.hackthechange.HeadsUp", category: "coordinator")

    private var streamTasks: [Task<Void, Never>] = []
    private var permissionTimer: Timer?
    private var diagnosticsTimer: Timer?
    private var isStarted = false

    public init(dependencies: Dependencies, settings: Settings, recorder: MotionRecorder? = nil) {
        let savedCalibration = dependencies.calibrationStore.load()
        var tiltRecognizer = TiltHoldRecognizer(config: TiltHoldConfig(settings: settings))
        tiltRecognizer.rollReference = savedCalibration?.neutralRoll ?? 0

        deps = dependencies
        self.settings = settings
        self.recorder = recorder ?? MotionRecorder()
        telemetry = LiveTelemetry()
        dispatcher = ActionDispatcher(cursor: dependencies.cursor, feedback: dependencies.feedback)
        permissionStatus = dependencies.permissions.currentStatus()
        calibration = savedCalibration
        needsRecenter = savedCalibration != nil
        poseFilter = PoseFilter(settings: settings)
        tilt = tiltRecognizer
        stillness = StillnessDetector(
            toleranceDegrees: settings.autoRecenterToleranceDegrees, duration: settings.autoRecenterStillDuration)
        dependencies.feedback.configure(volume: settings.feedbackVolume, muted: settings.feedbackMuted)
        dependencies.announcer.isEnabled = settings.speechEnabled
    }

    // MARK: Lifecycle

    public func start() {
        guard !isStarted else { return }
        isStarted = true
        let source = deps.motionSource
        streamTasks.append(Task { [weak self] in
            for await pose in source.poses { self?.handle(pose: pose) }
        })
        streamTasks.append(Task { [weak self] in
            for await change in source.connectionChanges { self?.handleConnection(change) }
        })
        // Starting motion right away also triggers the system motion permission prompt.
        source.start()
        startDiagnostics()
        refreshPermissions()
    }

    public func stop() {
        streamTasks.forEach { $0.cancel() }
        streamTasks.removeAll()
        permissionTimer?.invalidate()
        diagnosticsTimer?.invalidate()
        deps.motionSource.stop()
        deps.keepAlive.stop()
        isStarted = false
    }

    // MARK: Permissions

    public func refreshPermissions() {
        permissionStatus = deps.permissions.currentStatus()
        guard permissionStatus.isReady else {
            if state != .needsPermissions { enter(.needsPermissions) }
            startPermissionPolling()
            return
        }
        permissionTimer?.invalidate()
        permissionTimer = nil
        if state == .needsPermissions { proceed() }
    }

    /// Accessibility status doesn't notify on change, so poll while it's missing.
    private func startPermissionPolling() {
        guard permissionTimer == nil, settings.permissionPollInterval > 0 else { return }
        permissionTimer = Timer.scheduledTimer(withTimeInterval: settings.permissionPollInterval, repeats: true) {
            [weak self] _ in
            MainActor.assumeIsolated { self?.refreshPermissions() }
        }
    }

    // MARK: Headphones

    func handleConnection(_ change: HeadphoneConnection) {
        switch change {
        case .connected:
            guard !isHeadphonesConnected else { return }
            isHeadphonesConnected = true
            if state == .waitingForHeadphones || (state == .paused && pauseReason == .headphonesDisconnected) {
                pauseReason = nil
                proceed()
            }
        case .disconnected:
            guard isHeadphonesConnected else { return }
            isHeadphonesConnected = false
            needsRecenter = true  // the yaw reference resets on reconnect
            poseFilter.reset()
            switch state {
            case .tracking, .awaitingRecenter, .calibrating:
                pause(reason: .headphonesDisconnected)
            case .needsPermissions, .waitingForHeadphones, .paused:
                break
            }
        }
    }

    // MARK: Commands (gestures, menu, hotkey)

    public func togglePause() {
        switch state {
        case .paused: resume()
        case .tracking, .awaitingRecenter, .calibrating: pause(reason: .user)
        case .needsPermissions, .waitingForHeadphones: break
        }
    }

    public func recalibrate() {
        guard permissionStatus.isReady else { return }
        beginCalibration()
    }

    func pause(reason: PauseReason) {
        pauseReason = reason
        calibrationSession = nil
        enter(.paused)
        deps.feedback.play(.paused)
        switch reason {
        case .user: announce("Paused. Tilt your head left and hold to resume.")
        case .headphonesDisconnected: announce("Headphones disconnected. HeadsUp is paused.")
        }
    }

    func resume() {
        pauseReason = nil
        deps.feedback.play(.resumed)
        proceed()
        if state == .tracking { announce("Resumed.") }
    }

    /// Moves to whichever state the current conditions allow.
    func proceed() {
        if !permissionStatus.isReady {
            enter(.needsPermissions)
        } else if !isHeadphonesConnected {
            enter(.waitingForHeadphones)
        } else if calibration == nil {
            beginCalibration()
        } else if needsRecenter {
            stillness.reset()
            enter(.awaitingRecenter)
            announce("Look at the center of the screen and hold still to recenter.")
        } else {
            enterTracking(cursorAt: deps.cursor.currentPosition)
        }
    }

    func enter(_ newState: AppState) {
        holdProgress = nil
        state = newState
        switch newState {
        case .needsPermissions, .waitingForHeadphones: deps.keepAlive.stop()
        case .calibrating, .awaitingRecenter, .tracking, .paused: deps.keepAlive.start()
        }
    }

    /// Builds a fresh tracking pipeline. `cursorAt` makes the cursor glide from there.
    func enterTracking(cursorAt point: CGPoint?) {
        guard let calibration else { return }
        var engine = TrackingEngine(calibration: calibration, geometry: deps.screenGeometry(), settings: settings)
        engine.reset(cursorAt: point)
        self.engine = engine
        enter(.tracking)
    }

    /// The single gate for synthetic input.
    func post(_ body: () -> Void) {
        guard state.allowsEventPosting else { return }
        body()
    }

    func announce(_ text: String) {
        deps.announcer.announce(text)
    }

    // MARK: Diagnostics

    private func startDiagnostics() {
        let interval = max(settings.diagnosticsInterval, 0.25)
        diagnosticsTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.reportSampleRate(interval: interval) }
        }
    }
}
