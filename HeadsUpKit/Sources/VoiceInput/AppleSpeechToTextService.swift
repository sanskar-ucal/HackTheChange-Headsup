import AVFoundation
import CoreAudio
import Foundation
import QuartzCore
import Speech

/// `SFSpeechRecognizer` with on-device recognition when supported. Audio comes from the
/// Mac's built-in microphone by default: using the AirPods mic switches Bluetooth to the
/// low-quality call profile, which degrades audio and can disturb head tracking.
@MainActor
public final class AppleSpeechToTextService: SpeechToTextService {
    private let recognizer = SFSpeechRecognizer()
    private var engine: AVAudioEngine?
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var silenceTimer: Timer?
    private var handler: (@MainActor (SpeechEvent) -> Void)?
    private var latestText = ""
    private var lastSpeechTime: TimeInterval = 0
    private var silenceTimeout: TimeInterval = 1.5
    private var isActive = false

    public init() {}

    public var authorization: AuthorizationState {
        switch SFSpeechRecognizer.authorizationStatus() {
        case .authorized: return .authorized
        case .denied: return .denied
        case .restricted: return .restricted
        case .notDetermined: return .notDetermined
        @unknown default: return .notDetermined
        }
    }

    public func requestAuthorization() {
        SFSpeechRecognizer.requestAuthorization { _ in }
    }

    public func start(useBuiltInMicrophone: Bool, silenceTimeout: TimeInterval,
                      onEvent: @escaping @MainActor (SpeechEvent) -> Void) -> Bool {
        guard !isActive, authorization == .authorized, let recognizer, recognizer.isAvailable else { return false }
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        if recognizer.supportsOnDeviceRecognition { request.requiresOnDeviceRecognition = true }

        let engine = AVAudioEngine()
        if useBuiltInMicrophone, let device = BuiltInMicrophone.deviceID() {
            BuiltInMicrophone.select(device, on: engine.inputNode)
        }
        Self.installTap(on: engine.inputNode, feeding: request)
        engine.prepare()
        do { try engine.start() } catch {
            engine.inputNode.removeTap(onBus: 0)
            return false
        }

        self.engine = engine
        self.request = request
        handler = onEvent
        latestText = ""
        self.silenceTimeout = silenceTimeout
        // Give the user a moment to start speaking before silence ends the session.
        lastSpeechTime = CACurrentMediaTime() + silenceTimeout
        isActive = true
        task = Self.startTask(recognizer, request: request) { [weak self] text, isFinal, error in
            self?.handleResult(text: text, isFinal: isFinal, error: error)
        }
        silenceTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.checkSilence() }
        }
        return true
    }

    public func finish() {
        guard isActive else { return }
        // Stop the tap first so `append` and `endAudio` never overlap (see RecognitionAudioSink).
        engine?.inputNode.removeTap(onBus: 0)
        request?.endAudio()
        deliver(.final(latestText))
    }

    public func cancel() {
        guard isActive else { return }
        task?.cancel()
        teardown()
    }

    private func handleResult(text: String?, isFinal: Bool, error: String?) {
        guard isActive else { return }
        if let text, text != latestText {
            latestText = text
            lastSpeechTime = CACurrentMediaTime()
            handler?(.partial(text))
        }
        if isFinal {
            deliver(.final(latestText))
        } else if let error {
            deliver(latestText.isEmpty ? .failed(error) : .final(latestText))
        }
    }

    private func checkSilence() {
        if isActive && CACurrentMediaTime() - lastSpeechTime > silenceTimeout { finish() }
    }

    private func deliver(_ event: SpeechEvent) {
        let handler = self.handler
        teardown()
        handler?(event)
    }

    private func teardown() {
        isActive = false
        silenceTimer?.invalidate()
        silenceTimer = nil
        engine?.inputNode.removeTap(onBus: 0)
        engine?.stop()
        engine = nil
        request = nil
        task?.cancel()
        task = nil
        handler = nil
    }

    /// The tap runs on the audio thread, so it's built outside the main actor.
    private nonisolated static func installTap(on input: AVAudioInputNode, feeding request: SFSpeechAudioBufferRecognitionRequest) {
        let format = input.outputFormat(forBus: 0)
        let sink = RecognitionAudioSink(request)
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            sink.append(buffer)
        }
    }

    /// Recognition callbacks arrive on an arbitrary queue. Only plain Sendable values
    /// (text, flags, error message) are copied out of the result before hopping to the
    /// main actor; `SFSpeechRecognitionResult` itself never crosses.
    private nonisolated static func startTask(
        _ recognizer: SFSpeechRecognizer, request: SFSpeechAudioBufferRecognitionRequest,
        onResult: @escaping @MainActor @Sendable (String?, Bool, String?) -> Void
    ) -> SFSpeechRecognitionTask {
        recognizer.recognitionTask(with: request) { result, error in
            let text = result?.bestTranscription.formattedString
            let isFinal = result?.isFinal ?? false
            let message = error?.localizedDescription
            Task { @MainActor in onResult(text, isFinal, message) }
        }
    }
}

/// Hands microphone buffers from the audio tap thread to the recognition request.
///
/// `@unchecked Sendable` because `SFSpeechAudioBufferRecognitionRequest` is not annotated,
/// but appending buffers from an audio tap is its documented use: `append(_:)` is called
/// only from the single tap thread, and the main actor only calls `endAudio()` after the
/// tap is removed. No other state is shared. There is no Sendable alternative, since
/// `AVAudioPCMBuffer` is not Sendable either.
private final class RecognitionAudioSink: @unchecked Sendable {
    private let request: SFSpeechAudioBufferRecognitionRequest

    init(_ request: SFSpeechAudioBufferRecognitionRequest) {
        self.request = request
    }

    func append(_ buffer: AVAudioPCMBuffer) {
        request.append(buffer)
    }
}

/// Finds the Mac's built-in microphone and routes an `AVAudioInputNode` to it.
enum BuiltInMicrophone {
    static func deviceID() -> AudioDeviceID? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices, mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)
        var size: UInt32 = 0
        let system = AudioObjectID(kAudioObjectSystemObject)
        guard AudioObjectGetPropertyDataSize(system, &address, 0, nil, &size) == noErr else { return nil }
        var ids = [AudioDeviceID](repeating: 0, count: Int(size) / MemoryLayout<AudioDeviceID>.size)
        guard AudioObjectGetPropertyData(system, &address, 0, nil, &size, &ids) == noErr else { return nil }
        return ids.first { isBuiltIn($0) && hasInput($0) }
    }

    @discardableResult
    static func select(_ device: AudioDeviceID, on input: AVAudioInputNode) -> Bool {
        guard let unit = input.audioUnit else { return false }
        var id = device
        return AudioUnitSetProperty(unit, kAudioOutputUnitProperty_CurrentDevice, kAudioUnitScope_Global, 0,
                                    &id, UInt32(MemoryLayout<AudioDeviceID>.size)) == noErr
    }

    private static func isBuiltIn(_ device: AudioDeviceID) -> Bool {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyTransportType, mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)
        var transport: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        guard AudioObjectGetPropertyData(device, &address, 0, nil, &size, &transport) == noErr else { return false }
        return transport == kAudioDeviceTransportTypeBuiltIn
    }

    private static func hasInput(_ device: AudioDeviceID) -> Bool {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreams, mScope: kAudioObjectPropertyScopeInput,
            mElement: kAudioObjectPropertyElementMain)
        var size: UInt32 = 0
        return AudioObjectGetPropertyDataSize(device, &address, 0, nil, &size) == noErr && size > 0
    }
}
