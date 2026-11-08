import AVFoundation
import Foundation

/// Keeps motion delivery alive while HeadsUp is not the frontmost app.
@MainActor
public protocol BackgroundKeepAlive: AnyObject {
    func start()
    func stop()
}

/// Mitigation for background delivery (platform fact 8).
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
        do { try engine.start() } catch { }
    }

    static func observeConfigurationChanges(
        of engine: AVAudioEngine,
        handler: @escaping @MainActor @Sendable () -> Void
    ) -> NSObjectProtocol {
        NotificationCenter.default.addObserver(
            forName: .AVAudioEngineConfigurationChange, object: engine, queue: .main
        ) { _ in
            MainActor.assumeIsolated { handler() }
        }
    }
}
