import CoreGraphics
import Foundation

/// The coordinator's injected services, plus its settings and screen configuration API.
extension AppCoordinator {
    public struct Dependencies {
        public var motionSource: MotionSource
        public var cursor: CursorController
        public var scroll: ScrollController
        public var feedback: FeedbackService
        public var announcer: Announcer
        public var permissions: PermissionsProviding
        public var calibrationStore: CalibrationStoring
        public var keepAlive: BackgroundKeepAlive
        public var frameClock: FrameClock
        public var focusReader: FocusedElementReader
        public var speech: SpeechToTextService
        public var textInserter: TextInserter
        public var screenGeometry: @MainActor () -> ScreenGeometry
        public var isAppActive: @MainActor () -> Bool
        public var clock: @MainActor () -> TimeInterval
        public var schedule: @MainActor (TimeInterval, @escaping @MainActor @Sendable () -> Void) -> Void
        public var updateSettings: @MainActor (HeadsUpSettings) -> Void

        public init(
            motionSource: MotionSource, cursor: CursorController, scroll: ScrollController,
            feedback: FeedbackService, announcer: Announcer, permissions: PermissionsProviding,
            calibrationStore: CalibrationStoring, keepAlive: BackgroundKeepAlive, frameClock: FrameClock,
            focusReader: FocusedElementReader, speech: SpeechToTextService,
            textInserter: TextInserter,
            screenGeometry: @escaping @MainActor () -> ScreenGeometry,
            isAppActive: @escaping @MainActor () -> Bool,
            clock: @escaping @MainActor () -> TimeInterval,
            schedule: @escaping @MainActor (TimeInterval, @escaping @MainActor @Sendable () -> Void) -> Void,
            updateSettings: @escaping @MainActor (HeadsUpSettings) -> Void
        ) {
            self.motionSource = motionSource
            self.cursor = cursor
            self.scroll = scroll
            self.feedback = feedback
            self.announcer = announcer
            self.permissions = permissions
            self.calibrationStore = calibrationStore
            self.keepAlive = keepAlive
            self.frameClock = frameClock
            self.focusReader = focusReader
            self.speech = speech
            self.textInserter = textInserter
            self.screenGeometry = screenGeometry
            self.isAppActive = isAppActive
            self.clock = clock
            self.schedule = schedule
            self.updateSettings = updateSettings
        }
    }

    // MARK: Settings & screens

    public func apply(settings newSettings: HeadsUpSettings) {
        settings = newSettings
        poseFilter.configure(
            minCutoff: newSettings.filterMinCutoff, beta: newSettings.filterBeta, dCutoff: newSettings.filterDCutoff)
        tilt.config = TiltHoldConfig(settings: newSettings)
        stillness = StillnessDetector(
            toleranceDegrees: newSettings.autoRecenterToleranceDegrees, duration: newSettings.autoRecenterStillDuration)
        engine?.apply(newSettings)
        animator.stiffness = newSettings.pointerSpringStiffness
        modeRecognizer.inner.config = NodShakeConfig(settings: newSettings)
        modeRecognizer.config = DoubleNodConfig(settings: newSettings)
        deps.feedback.configure(volume: newSettings.feedbackVolume, muted: newSettings.feedbackMuted)
        deps.announcer.isEnabled = newSettings.speechEnabled
        updatePointerContext()
    }

    public func refreshGeometry() {
        engine?.geometry = deps.screenGeometry()
    }

    public var screenGeometry: ScreenGeometry { deps.screenGeometry() }

    public var pointingRect: CGRect { screenGeometry.pointingRect(spanAllDisplays: settings.spanAllDisplays) }
}
