import AppKit
import Combine
import HeadsUpKit

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

        let dependencies = AppCoordinator.Dependencies(
            motionSource: Self.makeMotionSource(),
            cursor: CGEventCursorController(),
            feedback: AudioFeedbackService(volume: settings.feedbackVolume, muted: settings.feedbackMuted),
            announcer: SpeechAnnouncer(isEnabled: settings.speechEnabled),
            permissions: permissions,
            calibrationStore: UserDefaultsCalibrationStore(),
            keepAlive: SilentAudioKeepAlive(),
            screenGeometry: { ScreenGeometry.current() },
            isAppActive: { NSApp.isActive })
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
