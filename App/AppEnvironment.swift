import AppKit
import Combine
import HeadsUpKit
import QuartzCore

/// Composition root: builds the concrete services and injects them into the coordinator.
@MainActor
final class AppEnvironment {
    let settingsStore: SettingsStore
    let permissions: SystemPermissionsService
    let coordinator: AppCoordinator
    private var cancellables: Set<AnyCancellable> = []

    init() {
        settingsStore = SettingsStore()
        permissions = SystemPermissionsService()
        let settings = settingsStore.settings
        let store = settingsStore

        let dependencies = AppCoordinator.Dependencies(
            motionSource: Self.makeMotionSource(),
            cursor: CGEventCursorController(),
            scroll: CGEventScrollController(),
            feedback: AudioFeedbackService(volume: settings.feedbackVolume, muted: settings.feedbackMuted),
            announcer: SpeechAnnouncer(isEnabled: settings.speechEnabled),
            permissions: permissions,
            calibrationStore: UserDefaultsCalibrationStore(),
            keepAlive: SilentAudioKeepAlive(),
            frameClock: DisplayLinkFrameClock(),
            focusReader: AXFocusedElementReader(messagingTimeout: Float(settings.axMessagingTimeout)),
            speech: AppleSpeechToTextService(),
            textInserter: AXTextInserter(),
            screenGeometry: { ScreenGeometry.current() },
            isAppActive: { NSApp.isActive },
            clock: { CACurrentMediaTime() },
            schedule: { delay, work in
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    MainActor.assumeIsolated { work() }
                }
            },
            updateSettings: { [weak store] in store?.settings = $0 },
            blinkSource: CameraBlinkSource())
        coordinator = AppCoordinator(dependencies: dependencies, settings: settings)

        settingsStore.$settings
            .dropFirst()
            .removeDuplicates()
            .sink { [weak coordinator] in coordinator?.apply(settings: $0) }
            .store(in: &cancellables)
    }

    /// Live AirPods by default. For demos and debugging without hardware, launch with
    /// `HEADSUP_REPLAY=/path/to/trace.csv` to loop a recorded trace instead.
    private static func makeMotionSource() -> MotionSource {
        if let path = ProcessInfo.processInfo.environment["HEADSUP_REPLAY"],
           let replay = try? ReplayMotionSource(csvURL: URL(fileURLWithPath: path), realtime: true, loops: true) {
            return replay
        }
        return HeadphoneMotionSource()
    }
}
