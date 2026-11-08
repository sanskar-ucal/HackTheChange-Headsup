import CoreGraphics
import Foundation
import OSLog

/// Progress of a hold (tilt-hold or auto-recenter) for the pointer ring.
public struct HoldProgress: Sendable, Equatable {
    public var gesture: HeadGesture
    public var fraction: Double
}

/// Owns the app state machine and wires motion → processing → output.
///
/// States: needsPermissions → waitingForHeadphones → calibrating → practicing → tracking,
/// with tracking ⇄ paused / scrollMode / listening → voiceReview. A launch with a saved
/// calibration, or a reconnect, goes through awaitingRecenter. Sensor samples update the
/// pointer *target*; `renderFrame(at:)` moves the real pointer at display rate. Synthetic
/// events go through `postMotion` / `postAction`, which check `AppState`.
@MainActor
public final class AppCoordinator: ObservableObject {
    @Published public internal(set) var state: AppState = .needsPermissions
    @Published public internal(set) var pauseReason: PauseReason?
    @Published public internal(set) var permissionStatus: PermissionStatus
    @Published public internal(set) var isHeadphonesConnected = false
    @Published public internal(set) var holdProgress: HoldProgress?
    @Published public internal(set) var calibrationProgress: Double = 0
    @Published public internal(set) var calibrationMessage: String?
    @Published public internal(set) var lastGesture: HeadGesture?
    @Published public internal(set) var pointerContext: PointerContext = .idle
    @Published public internal(set) var transcript = ""
    @Published public internal(set) var practice: PracticeSession?

    public let telemetry: LiveTelemetry
    public let recorder: MotionRecorder
    public internal(set) var settings: HeadsUpSettings
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

    // Rendering
    var animator: PointerAnimator
    var pointerTarget: CGPoint?
    var lastPostedPoint: CGPoint?
    var lastFrameTime: TimeInterval?
    /// True from a gesture onset until it is rejected, or until `freezeUntil` after a nod
    /// click: nothing moves the pointer.
    var pointerFrozen = false
    var frozenPoint: CGPoint?
    /// Frame-clock time when the hold after a click ends.
    var freezeUntil: TimeInterval?
    /// The next head target is reached with the release glide.
    var releaseGlidePending = false
    var glideOnNextTarget = false
    var pressingUntil: TimeInterval?
    var targetUpdatedAt: TimeInterval?
    var latestLatencyMs: Double?

    // Modes
    var scrollVelocity = ScrollVelocity.zero
    var scrollAnchor: CGPoint?
    var scrollMode: ScrollModeRecognizer?
    var modeRecognizer: DoubleNodRecognizer
    var voiceTarget: FocusedElement?
    var voiceInsertion: InsertionRecord?
    var voiceReviewStart: TimeInterval?
    var lastClickTime: TimeInterval = -.infinity

    static let log = Logger(subsystem: "com.hackthechange.HeadsUp", category: "coordinator")
    static let signposter = OSSignposter(subsystem: "com.hackthechange.HeadsUp", category: .pointsOfInterest)

    private var streamTasks: [Task<Void, Never>] = []
    private var permissionTimer: Timer?
    private var diagnosticsTimer: Timer?
    private var isStarted = false

    public init(dependencies: Dependencies, settings: HeadsUpSettings, recorder: MotionRecorder? = nil) {
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
        animator = PointerAnimator(stiffness: settings.pointerSpringStiffness)
        modeRecognizer = DoubleNodRecognizer(settings: settings)
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
        deps.frameClock.start { [weak self] timestamp in self?.renderFrame(at: timestamp) }
        deps.focusReader.onFocusChange = { [weak self] in self?.handleFocusChange() }
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
        deps.frameClock.stop()
        deps.speech.cancel()
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

    // MARK: Diagnostics

    private func startDiagnostics() {
        let interval = max(settings.diagnosticsInterval, 0.25)
        diagnosticsTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.reportSampleRate(interval: interval) }
        }
    }

    /// Called once per diagnostics interval on the wall clock, so a stall in background
    /// delivery shows up as 0 samples/s rather than a stale number.
    func reportSampleRate(interval: TimeInterval) {
        let rate = meter.takeRate(interval: interval)
        let active = deps.isAppActive()
        telemetry.samplesPerSecond = rate
        telemetry.isAppActive = active
        telemetry.pointerLatencyMs = latestLatencyMs
        if !active { telemetry.backgroundSamplesPerSecond = rate }
        guard isHeadphonesConnected else { return }
        Self.log.info(
            "motion samples/s=\(rate, format: .fixed(precision: 1), privacy: .public) frontmost=\(active, privacy: .public)")
    }
}
