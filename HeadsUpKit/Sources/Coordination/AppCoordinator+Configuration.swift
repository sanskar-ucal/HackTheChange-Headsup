import CoreGraphics
import Foundation

/// The coordinator's injected services, plus its settings and screen configuration API.
extension AppCoordinator {
    public struct Dependencies {
        public var motionSource: MotionSource
        public var cursor: CursorController
        public var feedback: FeedbackService
        public var announcer: Announcer
        public var permissions: PermissionsProviding
        public var calibrationStore: CalibrationStoring
        public var keepAlive: BackgroundKeepAlive
        public var screenGeometry: @MainActor () -> ScreenGeometry
        public var isAppActive: @MainActor () -> Bool

        public init(
            motionSource: MotionSource, cursor: CursorController, feedback: FeedbackService,
            announcer: Announcer, permissions: PermissionsProviding, calibrationStore: CalibrationStoring,
            keepAlive: BackgroundKeepAlive,
            screenGeometry: @escaping @MainActor () -> ScreenGeometry,
            isAppActive: @escaping @MainActor () -> Bool
        ) {
            self.motionSource = motionSource
            self.cursor = cursor
            self.feedback = feedback
            self.announcer = announcer
            self.permissions = permissions
            self.calibrationStore = calibrationStore
            self.keepAlive = keepAlive
            self.screenGeometry = screenGeometry
            self.isAppActive = isAppActive
        }
    }

    // MARK: Settings & screens

    public func apply(settings newSettings: Settings) {
        settings = newSettings
        poseFilter.configure(
            minCutoff: newSettings.filterMinCutoff, beta: newSettings.filterBeta, dCutoff: newSettings.filterDCutoff)
        tilt.config = TiltHoldConfig(settings: newSettings)
        stillness = StillnessDetector(
            toleranceDegrees: newSettings.autoRecenterToleranceDegrees, duration: newSettings.autoRecenterStillDuration)
        engine?.apply(newSettings)
        deps.feedback.configure(volume: newSettings.feedbackVolume, muted: newSettings.feedbackMuted)
        deps.announcer.isEnabled = newSettings.speechEnabled
    }

    public func refreshGeometry() {
        engine?.geometry = deps.screenGeometry()
    }

    public var screenGeometry: ScreenGeometry { deps.screenGeometry() }

    /// The global (top-left) rectangle head pointing maps onto.
    public var pointingRect: CGRect { screenGeometry.pointingRect(spanAllDisplays: settings.spanAllDisplays) }
}
