import AVFoundation
import Foundation

/// Keeps motion delivery alive while HeadsUp is not the frontmost app.
@MainActor
public protocol BackgroundKeepAlive: AnyObject {
    func start()
    func stop()
}

/// Mitigation for background delivery (platform fact 8):
/// - holds a `ProcessInfo` activity so App Nap does not throttle the process, and
/// - runs a silent `AVAudioEngine` output so the AirPods stay the active audio route
///   and the process counts as playing audio.
@MainActor
public final class SilentAudioKeepAlive: BackgroundKeepAlive {
    private let engine = AVAudioEngine()
    private var activity: NSObjectProtocol?
    private var configObserver: NSObjectProtocol?
    private var isRunning = false

    public init() {
        let silence = Self.makeSilenceNode()
        engine.attach(silence)
        let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)
        engine.connect(silence, to: engine.mainMixerNode, format: format)
    }

    /// Built outside the main actor: the render block runs on the real-time audio thread.
    private nonisolated static func makeSilenceNode() -> AVAudioSourceNode {
        AVAudioSourceNode { _, _, _, audioBufferList -> OSStatus in
            for buffer in UnsafeMutableAudioBufferListPointer(audioBufferList) {
                if let data = buffer.mData { memset(data, 0, Int(buffer.mDataByteSize)) }
            }
            return noErr
        }
    }

    public func start() {
        guard !isRunning else { return }
        isRunning = true
        activity = ProcessInfo.processInfo.beginActivity(
            options: [.userInitiated, .latencyCritical],
            reason: "HeadsUp head tracking drives the cursor in the background")
        configObserver = AudioEngineSupport.observeConfigurationChanges(of: engine) { [weak self] in
            self?.restartAfterConfigurationChange()
        }
        AudioEngineSupport.startIfNeeded(engine)
    }

    private func restartAfterConfigurationChange() {
        guard isRunning else { return }
        AudioEngineSupport.startIfNeeded(engine)
    }

    public func stop() {
        guard isRunning else { return }
        isRunning = false
        engine.stop()
        if let activity { ProcessInfo.processInfo.endActivity(activity) }
        activity = nil
        if let configObserver { NotificationCenter.default.removeObserver(configObserver) }
        configObserver = nil
    }
}

/// Shared AVAudioEngine housekeeping.
@MainActor
enum AudioEngineSupport {
    static func startIfNeeded(_ engine: AVAudioEngine) {
        guard !engine.isRunning else { return }
        engine.prepare()
        do { try engine.start() } catch { /* No output device right now; retried on route change. */ }
    }

    /// The engine stops when the output device changes (AirPods connect/disconnect).
    /// Calls `handler` on the main actor for each change so the owner can restart its
    /// engine. The engine is only the notification filter; it is not captured, so no
    /// non-Sendable state crosses into the observer block.
    static func observeConfigurationChanges(
        of engine: AVAudioEngine,
        handler: @escaping @MainActor @Sendable () -> Void
    ) -> NSObjectProtocol {
        NotificationCenter.default.addObserver(
            forName: .AVAudioEngineConfigurationChange, object: engine, queue: .main
        ) { _ in
            // queue: .main delivers on the main thread.
            MainActor.assumeIsolated { handler() }
        }
    }
}
